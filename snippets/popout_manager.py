from __future__ import annotations
import math
import time
from typing import TYPE_CHECKING, Callable
from loguru import logger
from fabric.widgets.wayland import WaylandWindow
from fabric.widgets.box import Box
from fabric.widgets.eventbox import EventBox
from gi.repository import Gtk, GtkLayerShell, Gdk, GLib
from snippets.blur.blur import enable_blur, is_blur_supported

if TYPE_CHECKING:
    from bar import Bar

EDGE_MARGIN = 12

def _get_monitor_geometry(widget: Gtk.Widget | None) -> tuple[int, int, int]:
    if widget is not None:
        if hasattr(widget, "gdk_monitor") and widget.gdk_monitor:
            geo = widget.gdk_monitor.get_geometry()
            return geo.x, geo.width, geo.height
        if hasattr(widget, "monitor_id") and widget.monitor_id is not None:
            display = Gdk.Display.get_default()
            if display and 0 <= widget.monitor_id < display.get_n_monitors():
                mon = display.get_monitor(widget.monitor_id)
                if mon:
                    geo = mon.get_geometry()
                    return geo.x, geo.width, geo.height

    screen = Gdk.Screen.get_default()
    if widget is not None:
        toplevel = widget.get_toplevel() if hasattr(widget, "get_toplevel") else None
        if toplevel and hasattr(toplevel, "get_window"):
            window = toplevel.get_window()
            if window is not None and screen is not None:
                monitor_index = screen.get_monitor_at_window(window)
                geo = screen.get_monitor_geometry(monitor_index)
                return geo.x, geo.width, geo.height

    if screen is not None:
        return 0, screen.get_width(), screen.get_height()
    return 0, 1920, 1080

def _get_coords_for_widget(widget: Gtk.Widget) -> tuple[int, int]:
    if not ((toplevel := widget.get_toplevel()) and toplevel.is_toplevel()):
        return 0, 0
    coords = widget.translate_coordinates(toplevel, 0, 0)
    if coords is not None:
        return coords[0], coords[1]
    allocation = widget.get_allocation()
    return allocation.x, allocation.y


class PopoutScrim(WaylandWindow):
    """
    Subtle desktop dimming scrim that captures clicks outside the popout and closes it.
    Leaves the bar area uncovered so clicking other bar pills is immediately handled by the bar.
    """
    def __init__(self, bar: "Bar", on_dismiss: Callable[[], None], **kwargs):
        self._bar = bar
        self._on_dismiss = on_dismiss
        self._event_box = EventBox(style_classes=["desktop-scrim"])
        self._event_box.connect("button-release-event", lambda *_: self._on_dismiss())

        monitor = bar.monitor_id if hasattr(bar, "monitor_id") else 0

        super().__init__(
            anchor="left right top bottom",
            layer="top",
            keyboard_mode="none",
            monitor=monitor,
            child=self._event_box,
            visible=False,
            **kwargs,
        )
        self.update_margin()
        bar.connect("size-allocate", lambda *_: self.update_margin())

    def update_margin(self):
        if not self._bar:
            return
        offset = self._bar.get_allocated_height()
        if offset <= 1:
            offset = self._bar.get_preferred_size()[1].height
        if offset <= 1:
            offset = 40

        alignment = getattr(self._bar, "alignment", "top")
        if alignment == "bottom":
            self.margin = (0, 0, offset, 0)
        else:
            self.margin = (offset, 0, 0, 0)


class UnifiedPopoutManager:
    """
    A single, persistent Wayland LayerShell popout surface for a given Bar.
    Tracks active bar pills with smooth sliding physics, cross-fades content,
    and manages the desktop dimming scrim.
    """

    def __init__(self, bar: "Bar", applet_factories: dict[str, type]):
        self.bar = bar
        self.applet_factories = applet_factories
        self.is_open: bool = False
        self._current_key: str | None = None
        self._current_anchor: Gtk.Widget | None = None
        self._current_left: int = 0
        self._slide_timer: int | None = None
        self._fade_timer: int | None = None
        self._cached_applets: dict[str, Gtk.Widget] = {}

        # Content Stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(180)

        self.container = Box(
            style_classes=["applet-popout-container"],
            children=[self.stack]
        )

        is_bottom = getattr(self.bar, "alignment", "top") == "bottom"
        anchor = "left bottom" if is_bottom else "left top"

        self.window = WaylandWindow(
            title="agility-shell-unified-popout",
            anchor=anchor,
            layer="top",
            exclusivity="none",
            keyboard_mode="on-demand",
            monitor=bar.monitor_id if hasattr(bar, "monitor_id") else 0,
            style_classes=["applet-popout-window", "applet-window"],
            child=self.container,
            visible=False,
        )

        try:
            GtkLayerShell.set_exclusive_zone(self.window, -1)
        except Exception:
            pass

        self.window.add_keybinding("escape", lambda: self.close())
        self.window.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)

        # Scrim for outside click dismissal and subtle dimming
        self.scrim = PopoutScrim(bar=self.bar, on_dismiss=self.close)

        # Enable compositor blur on the popout window if supported
        try:
            if is_blur_supported():
                enable_blur(self.window)
        except Exception as e:
            logger.debug(f"[PopoutManager] blur initialization: {e}")

        # Recalculate margins when bar or popout size changes
        self.window.connect("size-allocate", self._on_size_allocate)
        self.bar.connect("size-allocate", self._on_bar_size_allocate)

    def _on_bar_size_allocate(self, *_):
        if self.is_open and self._current_anchor:
            self._update_position(animate=False)

    def _on_size_allocate(self, *_):
        if self.is_open and self._current_anchor:
            self._update_position(animate=False)

    def _ensure_applet_widget(self, key: str) -> Gtk.Widget | None:
        if key in self._cached_applets:
            return self._cached_applets[key]

        factory = self.applet_factories.get(key)
        if not factory:
            return None

        try:
            widget = factory(self.window)
            wrapper = Box(
                style_classes=["applet"],
                children=[widget]
            )
            wrapper.show_all()
            self._cached_applets[key] = wrapper
            self.stack.add_named(wrapper, key)
            return wrapper
        except Exception as e:
            logger.error(f"[PopoutManager] Error creating applet for key '{key}': {e}")
            return None

    def _calculate_target_left(self, anchor_widget: Gtk.Widget) -> int:
        monitor_x, monitor_width, _ = _get_monitor_geometry(self.bar)

        popout_width = self.window.get_allocated_width()
        if popout_width <= 1:
            popout_width = self.window.get_preferred_size()[1].width
        if popout_width <= 1:
            popout_width = 340

        bar_width = self.bar.get_allocated_width()
        if bar_width <= 1:
            bar_width = self.bar.get_preferred_size()[1].width

        parent_margin = getattr(self.bar, "margin", (0, 0, 0, 0))
        parent_margin_vals = tuple(parent_margin) if hasattr(parent_margin, "__iter__") else (0, 0, 0, 0)
        parent_right_margin = parent_margin_vals[1] if len(parent_margin_vals) > 1 else 0
        parent_left_margin = parent_margin_vals[3] if len(parent_margin_vals) > 3 else 0

        h_align = getattr(self.bar, "horizontal_alignment", "center")
        min_width = getattr(self.bar, "min_width", False)
        is_left = GtkLayerShell.get_anchor(self.bar, GtkLayerShell.Edge.LEFT)
        is_right = GtkLayerShell.get_anchor(self.bar, GtkLayerShell.Edge.RIGHT)

        if not min_width or (is_left and is_right):
            bar_screen_left = parent_left_margin
        elif h_align == "left" or (is_left and not is_right):
            bar_screen_left = parent_left_margin
        elif h_align == "right" or (is_right and not is_left):
            bar_screen_left = monitor_width - bar_width - parent_right_margin
        else:
            bar_screen_left = (monitor_width - bar_width) // 2

        coords = _get_coords_for_widget(anchor_widget)
        widget_width = anchor_widget.get_allocated_width()
        widget_center_in_bar = coords[0] + (widget_width / 2.0)

        screen_widget_center_x = bar_screen_left + widget_center_in_bar
        raw_margin_left = round(screen_widget_center_x - (popout_width / 2.0))

        min_margin = EDGE_MARGIN
        max_margin = max(EDGE_MARGIN, monitor_width - popout_width - EDGE_MARGIN)
        return max(min_margin, min(raw_margin_left, max_margin))

    def _get_vertical_offset(self) -> int:
        offset = self.bar.get_allocated_height()
        if offset <= 1:
            offset = self.bar.get_preferred_size()[1].height
        if offset <= 1:
            offset = 40
        return offset + 8

    def _set_left_margin(self, left: int):
        self._current_left = left
        is_bottom = getattr(self.bar, "alignment", "top") == "bottom"
        offset = self._get_vertical_offset()
        if is_bottom:
            self.window.margin = (0, 0, offset, left)
        else:
            self.window.margin = (offset, 0, 0, left)

    def _animate_to_left(self, target_left: int, duration_ms: int = 180):
        if self._slide_timer is not None:
            GLib.source_remove(self._slide_timer)
            self._slide_timer = None

        start_left = self._current_left
        delta = target_left - start_left
        if abs(delta) < 2:
            self._set_left_margin(target_left)
            return

        start_time = time.time()
        duration_s = duration_ms / 1000.0

        def _step():
            elapsed = time.time() - start_time
            progress = min(1.0, elapsed / duration_s)
            # Cubic ease-out: 1 - (1 - t)^3
            eased = 1.0 - math.pow(1.0 - progress, 3)
            current = int(start_left + delta * eased)
            self._set_left_margin(current)

            if progress >= 1.0:
                self._slide_timer = None
                self._set_left_margin(target_left)
                return GLib.SOURCE_REMOVE
            return GLib.SOURCE_CONTINUE

        self._slide_timer = GLib.timeout_add(16, _step)

    def _update_position(self, animate: bool = True):
        if not self._current_anchor:
            return
        target_left = self._calculate_target_left(self._current_anchor)
        if animate and self.is_open:
            self._animate_to_left(target_left)
        else:
            self._set_left_margin(target_left)

    def toggle(self, key: str, anchor_widget: Gtk.Widget) -> bool:
        """
        Toggle the popout for the given key and anchor.
        If already open for this key, closes it.
        If open for another key, seamlessly transitions to this one.
        """
        if self.is_open and self._current_key == key:
            self.close()
            return False
        self.open(key, anchor_widget)
        return True

    def open(self, key: str, anchor_widget: Gtk.Widget):
        """Open or smoothly transition to the given key and anchor."""
        widget = self._ensure_applet_widget(key)
        if not widget:
            return

        is_switching = self.is_open and self._current_key != key

        # Clear active class on previous anchor
        if self._current_anchor and self._current_anchor != anchor_widget:
            self._current_anchor.remove_style_class("active-popout")
            self._current_anchor.remove_style_class("applet-open")

        self._current_key = key
        self._current_anchor = anchor_widget
        self.is_open = True

        # Add active classes to new anchor
        anchor_widget.add_style_class("active-popout")
        anchor_widget.add_style_class("applet-open")

        # Switch content in stack
        self.stack.set_visible_child_name(key)

        if is_switching:
            # Popout is already visible; smoothly slide to new position
            self._update_position(animate=True)
        else:
            # First open: set position immediately, then reveal
            self._update_position(animate=False)
            self.scrim.update_margin()
            self.scrim.set_visible(True)
            self.scrim.show()
            self.window.set_visible(True)
            self.window.show_all()

    def close(self):
        """Close the popout and scrim gracefully."""
        if not self.is_open:
            return

        if self._slide_timer is not None:
            GLib.source_remove(self._slide_timer)
            self._slide_timer = None

        if self._current_anchor:
            self._current_anchor.remove_style_class("active-popout")
            self._current_anchor.remove_style_class("applet-open")

        self.is_open = False
        self._current_key = None
        self._current_anchor = None

        self.window.set_visible(False)
        self.scrim.set_visible(False)
