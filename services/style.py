import os
from fabric.core.service import Service, Property
from fabric.utils import monitor_file
from gi.repository import GLib
from plugin_loader import apply_plugin_css
from services.paths import get_user_config_dir, resolve_style_file


class StyleService(Service):

    def __init__(self, app, **kwargs):
        super().__init__(**kwargs)
        self.app = app
        self._style_changed = False

        style_dir = os.path.join(get_user_config_dir(), "style")
        os.makedirs(style_dir, exist_ok=True)
        self.style_monitor = monitor_file(style_dir)
        self.style_monitor.connect("changed", lambda *_: self.reload())

    @Property(bool, default_value=False)
    def style_changed(self) -> bool:
        return self._style_changed

    def reload(self, *_):
        try:
            target_style = resolve_style_file("style.css")

            if os.path.isfile(target_style):
                self.app.set_stylesheet_from_file(
                    file_path=target_style,
                )
            
            GLib.timeout_add(100, apply_plugin_css, self.app)

            self._style_changed = not self._style_changed
            
            self.notify("style-changed")
            
        except Exception as e:
            print(f"[StyleService] Error reloading styles: {e}")
