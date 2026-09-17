from fabric.widgets.box import Box
from fabric.widgets.label import Label
from fabric.widgets.eventbox import EventBox
from snippets import AnimatedCircularScale
from gi.repository import Gdk

VARIANT_ICON = "icon"
VARIANT_ICON_LABEL = "icon+label"
VARIANT_SCALE = "scale"
VARIANT_SCALE_LABEL = "scale+label"
VARIANT_LABEL = "label"

VARIANT_CSS = {
    VARIANT_ICON: "variant-icon",
    VARIANT_ICON_LABEL: "variant-icon-label",
    VARIANT_SCALE: "variant-scale",
    VARIANT_SCALE_LABEL: "variant-scale-label",
}

def get_default_scale_size() -> int:
    try:
        from user_options import user_options
        bh = getattr(user_options.settings, "bar_height", 36)
        if bh >= 46:
            return 32
        elif bh >= 40:
            return 28
        elif bh >= 34:
            return 24
        elif bh >= 30:
            return 22
        return 20
    except Exception:
        return 24

class BaseButton(EventBox):
    VARIANTS = [VARIANT_ICON, VARIANT_LABEL, VARIANT_ICON_LABEL]

    def __init__(self, icon, label: str = "", variant: str = VARIANT_ICON_LABEL, **kwargs):
        self._icon = icon
        self._label_widget = Label(label=label)
        self._variant = variant
        # self._label_widget.set_yalign(0.55)
        style_classes = ["bar-button", VARIANT_CSS.get(variant, "variant-icon-label")]

        if variant == VARIANT_LABEL:
            children = [self._label_widget]
        elif variant == VARIANT_ICON_LABEL:
            children = [self._icon, self._label_widget]
        else:
            children = [self._icon]

        super().__init__(
            child=Box(
                style_classes=style_classes,
                spacing=4,
                children=children,
            ),
            **kwargs,
        )

    def _update_label(self, text: str):
        self._label_widget.set_label(text)

    def _update_icon(self, icon_name: str):
        self._icon.set_property("icon-name", icon_name)

class ProgressButton(Box):
    VARIANTS = [VARIANT_ICON, VARIANT_SCALE, VARIANT_ICON_LABEL, VARIANT_SCALE_LABEL]

    def __init__(self, icon, label="", variant=VARIANT_SCALE_LABEL,
                size=None, icon_size=16, icon_size_standalone=16, line_width=2, **kwargs):
        self._variant = variant
        self._label_widget = Label(label=label)
        # self._label_widget.set_yalign(0.55)
        self.scale = None
        if size is None or size == 32:
            size = get_default_scale_size()

        if callable(icon):
            built_icon = icon(icon_size) if variant in (VARIANT_SCALE, VARIANT_SCALE_LABEL) else icon(icon_size_standalone)
        else:
            built_icon = icon

        style_classes = ["bar-button", VARIANT_CSS.get(variant, "variant-scale-label")]

        if variant in (VARIANT_SCALE, VARIANT_SCALE_LABEL):
            self.scale = AnimatedCircularScale(
                style_classes=["circular-scale"],
                start_angle=90,
                end_angle=450,
                size=(size, size),
                min_value=0,
                max_value=100,
                value=0,
                line_width=line_width,
                child=Box(
                    size=(icon_size, icon_size),
                    h_align="center",
                    v_align="center",
                    children=[built_icon],
                ),
            )
            children = [self.scale]
            if variant == VARIANT_SCALE_LABEL:
                children.append(self._label_widget)
        else:
            children = [built_icon]
            if variant == VARIANT_ICON_LABEL:
                children.append(self._label_widget)

        super().__init__(
            style_classes=style_classes,
            spacing=4,
            children=children,
            **kwargs,
        )

    def _update_value(self, value: float):
        if self.scale:
            self.scale.set_value(value)

    def _update_label(self, text: str):
        self._label_widget.set_label(text)

    def apply_bar_height(self, height: int):
        if height >= 46:
            new_size = 32
        elif height >= 40:
            new_size = 28
        elif height >= 34:
            new_size = 24
        elif height >= 30:
            new_size = 22
        else:
            new_size = 20
        if self.scale:
            self.scale.set_size_request(new_size, new_size)
            try:
                inner = self.scale.get_child()
                if inner:
                    inner_icon_sz = min(16, max(12, new_size - 4))
                    inner.set_size_request(inner_icon_sz, inner_icon_sz)
            except Exception:
                pass

class StatButton(Box):
    """
    Base class for scrollable stat buttons (volume, brightness, etc).

    Subclasses should:
      - Call super().__init__(...) with their icon, label, and variant
      - Override _adjust(direction: int) to handle scroll actions
      - Connect their own signals and call self._update_label() / self._update_value()

    Variants:
      "icon"             → icon only, no label, no scale
      "icon+label"       → icon + percent label
      "scale"            → circular scale (icon inside), no label
      "scale+label"      → circular scale (icon inside) + percent label
    """

    VARIANTS = [VARIANT_ICON, VARIANT_SCALE, VARIANT_ICON_LABEL, VARIANT_SCALE_LABEL]

    def __init__(self, icon, label="", variant=VARIANT_ICON_LABEL,
                size=None, icon_size=16, icon_size_standalone=16, line_width=2, **kwargs):
        self._variant = variant
        self._label_widget = Label(label=label)
        # self._label_widget.set_yalign(0.55)
        self.scale = None
        self._scroll_accumulator = 0.0
        if size is None or size == 32:
            size = get_default_scale_size()

        if callable(icon):
            actual_icon_scale = icon(icon_size)
            actual_icon_standalone = icon(icon_size_standalone)
        else:
            actual_icon_scale = icon
            actual_icon_standalone = icon

        if variant in (VARIANT_SCALE, VARIANT_SCALE_LABEL):
            built_icon = actual_icon_scale
        else:
            built_icon = actual_icon_standalone
        style_classes = ["bar-button", VARIANT_CSS.get(variant, "variant-icon-label")]

        if variant in (VARIANT_SCALE, VARIANT_SCALE_LABEL):
            self.scale = AnimatedCircularScale(
                style_classes=["circular-scale", "editable"],
                start_angle=90,
                end_angle=450,
                size=(size, size),
                min_value=0,
                max_value=100,
                value=0,
                line_width=line_width,
                child=Box(
                    size=(icon_size, icon_size),
                    h_align="center",
                    v_align="center",
                    children=[built_icon],
                ),
            )
            children = [self.scale]
            if variant == VARIANT_SCALE_LABEL:
                children.append(self._label_widget)
        else:
            children = [built_icon]
            if variant == VARIANT_ICON_LABEL:
                children.append(self._label_widget)

        inner = Box(
            style_classes=style_classes,
            spacing=4,
            children=children,
        )
        self._event_box = EventBox(
            events=["scroll", "smooth-scroll"],
            child=inner,
            on_scroll_event=self._on_scroll,
        )

        super().__init__(
            children=[self._event_box],
            **kwargs,
        )

    def _on_scroll(self, _, event):
        if event.direction == Gdk.ScrollDirection.SMOOTH:
            _, dx, dy = event.get_scroll_deltas()
            self._scroll_accumulator += dy
            if abs(self._scroll_accumulator) >= 1.0:
                self._adjust(int(self._scroll_accumulator))
                self._scroll_accumulator = 0.0
        else:
            match event.direction:
                case Gdk.ScrollDirection.UP:
                    self._adjust(-1)
                case Gdk.ScrollDirection.DOWN:
                    self._adjust(1)

    def _adjust(self, direction: int):
        """Override in subclass to handle scroll adjustments."""

    def _update_label(self, text: str):
        self._label_widget.set_label(text)

    def _update_value(self, value: float):
        if self.scale:
            self.scale.animate_value(value)

    def apply_bar_height(self, height: int):
        if height >= 46:
            new_size = 32
        elif height >= 40:
            new_size = 28
        elif height >= 34:
            new_size = 24
        elif height >= 30:
            new_size = 22
        else:
            new_size = 20
        if self.scale:
            self.scale.set_size_request(new_size, new_size)
            try:
                inner = self.scale.get_child()
                if inner:
                    inner_icon_sz = min(16, max(12, new_size - 4))
                    inner.set_size_request(inner_icon_sz, inner_icon_sz)
            except Exception:
                pass