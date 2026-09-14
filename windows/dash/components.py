import math
import cairo
from typing import cast
from fabric.widgets.box import Box
from fabric.widgets.centerbox import CenterBox
from fabric.widgets.button import Button
from fabric.widgets.label import Label
from fabric.widgets.grid import Grid
from fabric.widgets.stack import Stack
from snippets import Icon, ClippingScrolledWindow, StyleAwareEntry

class DashHeader(CenterBox):
    def __init__(self):
        self._entry = StyleAwareEntry(h_expand=True, h_align="fill", placeholder="Type to search...")
        self._entry_box = Box(
            style_classes=["launcher-search"],
            spacing=8,
            style="min-width: 240px; margin-right: 4px;",
            visible=False,
            children=[
                Icon(icon_name="magnifying-glass-duotone", icon_size=16),
                self._entry,
            ],
        )
        self._entry.connect("focus-in-event", lambda *_: self._entry_box.add_style_class("focused"))
        self._entry.connect("focus-out-event", lambda *_: self._entry_box.remove_style_class("focused"))

        self._refresh_icon = Icon(icon_name="arrows-clockwise-duotone", icon_size=16)
        self._refresh_btn = Button(
            style_classes=["dash-header-button"],
            child=self._refresh_icon,
            tooltip_text="Refresh applications",
            visible=False,
            on_pressed=lambda *_: self._on_refresh_pressed(),
        )
        self._refresh_callback = None

        self._left_box = Box(style_classes=["dash-header-button-container"], orientation="h", spacing=6)
        self._right_box = Box(style_classes=["dash-header-button-container"], orientation="h", spacing=6)

        self._current_is_secondary: bool | None = None
        self._primary_btn_cache: dict[str, Button] = {}
        self._secondary_btn_cache: dict[str, Button] = {}
        self._v_btn_left: Button | None = None
        self._v_btn_right: Button | None = None
        self._v_icon_left = Icon(icon_name="diamonds-four-duotone")
        self._v_icon_right = Icon(icon_name="images-duotone")
        self._v_callback = None

        super().__init__(
            h_expand=False,
            h_align="center",
            style="min-width: 1104px",
            start_children=self._left_box,
            end_children=self._right_box,
        )

    def _on_refresh_pressed(self):
        if self._refresh_callback:
            self._refresh_callback()

    def _get_or_create_button(self, name: str, icon: str, label: str, cb, cache: dict) -> Button:
        if name not in cache:
            btn = Button(
                style_classes=["dash-header-button"],
                child=Box(
                    orientation="h",
                    spacing=6,
                    children=[
                        Icon(icon_name=icon),
                        Label(label=label),
                    ],
                ),
            )
            btn._dash_cb = cb
            btn.connect("pressed", lambda b: b._dash_cb() if getattr(b, "_dash_cb", None) else None)
            cache[name] = btn
        else:
            cache[name]._dash_cb = cb
        return cache[name]

    def update(
        self,
        *,
        current_page: str,
        primary_tabs: list,
        secondary_tabs: list,
        v_icon: str,
        v_callback,
        show_search: bool = False,
        is_secondary: bool = False,
        refresh_callback=None,
    ):
        self._v_callback = v_callback
        self._refresh_callback = refresh_callback
        mode_changed = (self._current_is_secondary != is_secondary)
        self._current_is_secondary = is_secondary

        if is_secondary:
            if mode_changed:
                for child in self._left_box.get_children():
                    self._left_box.remove(child)
                for child in self._right_box.get_children():
                    self._right_box.remove(child)

                if self._v_btn_left is None:
                    self._v_btn_left = Button(
                        style_classes=["dash-header-button"],
                        child=self._v_icon_left,
                        on_pressed=lambda *_: self._v_callback() if self._v_callback else None,
                    )
                self._left_box.add(self._v_btn_left)

                for name, icon, label, cb in secondary_tabs:
                    btn = self._get_or_create_button(name, icon, label, cb, self._secondary_btn_cache)
                    self._right_box.add(btn)

                self._left_box.show_all()
                self._right_box.show_all()

            self._v_icon_left.set_icon_name(v_icon)
            for name, _, _, cb in secondary_tabs:
                btn = self._get_or_create_button(name, "", "", cb, self._secondary_btn_cache)
                if name == current_page:
                    btn.add_style_class("active")
                else:
                    btn.remove_style_class("active")

            self._refresh_btn.set_visible(False)
            self._entry_box.set_visible(False)
            self._entry.set_text("")
        else:
            if mode_changed:
                for child in self._left_box.get_children():
                    self._left_box.remove(child)
                for child in self._right_box.get_children():
                    self._right_box.remove(child)

                for name, icon, label, cb in primary_tabs:
                    btn = self._get_or_create_button(name, icon, label, cb, self._primary_btn_cache)
                    self._left_box.add(btn)

                self._right_box.add(self._entry_box)
                self._right_box.add(self._refresh_btn)

                if self._v_btn_right is None:
                    self._v_btn_right = Button(
                        style_classes=["dash-header-button"],
                        child=self._v_icon_right,
                        on_pressed=lambda *_: self._v_callback() if self._v_callback else None,
                    )
                self._right_box.add(self._v_btn_right)

                self._left_box.show_all()
                self._right_box.show_all()

            self._v_icon_right.set_icon_name(v_icon)
            for name, _, _, cb in primary_tabs:
                btn = self._get_or_create_button(name, "", "", cb, self._primary_btn_cache)
                if name == current_page:
                    btn.add_style_class("active")
                else:
                    btn.remove_style_class("active")

            self._entry_box.set_visible(show_search)
            self._refresh_btn.set_visible(refresh_callback is not None)
            if not show_search:
                self._entry.set_text("")

class DashGrid(Grid):
    def __init__(self, children):
        super().__init__(
            column_homogeneous=False,
            column_spacing=12,
            row_spacing=12,
        )
        for child in children:
            self.attach_flow(child, 6)

class DashPage(Box):
    """Grid-based page — no header of its own."""

    def __init__(self, grid_children):
        self.grid = DashGrid(children=grid_children)
        self.scroll = ClippingScrolledWindow(
            h_expand=False,
            h_align="center",
            style_classes=["dash-grid"],
            child=self.grid,
            max_content_size=(1104, 604),
            fade_distance=56,
            overlay_scroll=True,
            kinetic_scroll=True,
        )
        self.scroll.set_size_request(1104, 604)
        super().__init__(
            orientation="v",
            v_align="center",
            spacing=60,
            children=[
                self.scroll
            ],
        )

class DashGroup(Stack):
    def __init__(self, transition_type="slide-left-right"):
        super().__init__(
            style_classes=["dash-stack"],
            h_expand=False,
            h_align="center",
            transition_type=transition_type,
            transition_duration=220,
        )
        self.set_vhomogeneous(True)
        self.set_hhomogeneous(True)
        self.set_interpolate_size(False)

    def do_draw(self, cr: cairo.Context):
        cr.save()
        width = self.get_allocated_width()
        height = self.get_allocated_height()
        try:
            radius = cast(
                int,
                self.get_style_context().get_property(
                    "border-radius", self.get_state_flags()
                ),
            )
        except Exception:
            radius = 0
        if radius > 0:
            cr.move_to(radius, 0)
            cr.line_to(width - radius, 0)
            cr.arc(width - radius, radius, radius, -(math.pi / 2), 0)
            cr.line_to(width, height - radius)
            cr.arc(width - radius, height - radius, radius, 0, (math.pi / 2))
            cr.line_to(radius, height)
            cr.arc(radius, height - radius, radius, (math.pi / 2), math.pi)
            cr.line_to(0, radius)
            cr.arc(radius, radius, radius, math.pi, (3 * (math.pi / 2)))
            cr.close_path()
            cr.clip()
        Stack.do_draw(self, cr)
        cr.restore()
        return True
