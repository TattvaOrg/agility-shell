from .button import QSButton
from snippets import Icon
from services.singletons import caffeine

class CaffieneButton(QSButton):
    def __init__(self, **kwargs):
        super().__init__(
            icon=Icon(icon_name="coffee-duotone"),
            on_activate=lambda _: self.set_active(True),
            on_deactivate=lambda _: self.set_active(False),
            **kwargs,
        )

        caffeine.connect(
            "notify::enabled",
            lambda obj, _: setattr(self, "active", obj.enabled),
        )
        self.active = caffeine.enabled

    def set_active(self, value: bool):
        caffeine.enabled = value
        setattr(self, "active", value)