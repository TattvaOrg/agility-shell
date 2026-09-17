import os
import re
from fabric.core.service import Service, Property
from fabric.utils import monitor_file
from gi.repository import GLib
from loguru import logger
from plugin_loader import apply_plugin_css
from services.paths import get_user_config_dir, get_repo_dir, resolve_style_file


def compile_resolved_stylesheet() -> str | None:
    """
    Loads style.css and resolves every @import "<file>" with resolve_style_file(fname),
    ensuring user overrides in ~/.config/agility-shell/style/ (such as Matugen-generated
    colors.css, user borders.css, user fonts.css) take precedence over static repo defaults.
    Also appends custom.css if present in the user style directory.
    """
    target_style = resolve_style_file("style.css")
    if not os.path.isfile(target_style):
        return None

    try:
        with open(target_style, "r") as f:
            content = f.read()

        def _replace_import(match: re.Match) -> str:
            fname = match.group(1).strip()
            resolved = resolve_style_file(fname)
            if os.path.isfile(resolved):
                return f'@import "{resolved}";'
            return match.group(0)

        resolved_css = re.sub(r'@import\s+(?:url\()?["\']?([^"\')]+)["\']?\)?\s*;', _replace_import, content)

        user_custom = os.path.join(get_user_config_dir(), "style", "custom.css")
        if os.path.isfile(user_custom):
            resolved_css += f'\n@import "{user_custom}";\n'

        return resolved_css
    except Exception as e:
        logger.error(f"[StyleService] Error resolving stylesheet: {e}")
        return None


class StyleService(Service):

    def __init__(self, app, **kwargs):
        super().__init__(**kwargs)
        self.app = app
        self._style_changed = False
        self._reload_timer_id: int | None = None

        style_dir = os.path.join(get_user_config_dir(), "style")
        os.makedirs(style_dir, exist_ok=True)
        self.style_monitor = monitor_file(style_dir)
        self.style_monitor.connect("changed", self._on_style_file_changed)

        repo_style_dir = os.path.join(get_repo_dir(), "style")
        if os.path.isdir(repo_style_dir) and os.path.abspath(repo_style_dir) != os.path.abspath(style_dir):
            try:
                self.repo_style_monitor = monitor_file(repo_style_dir)
                self.repo_style_monitor.connect("changed", self._on_style_file_changed)
            except Exception as e:
                logger.debug(f"[StyleService] Repo style monitor not attached: {e}")

    def _on_style_file_changed(self, *_):
        if self._reload_timer_id is not None:
            GLib.source_remove(self._reload_timer_id)
        self._reload_timer_id = GLib.timeout_add(100, self._debounced_reload)

    def _debounced_reload(self):
        self._reload_timer_id = None
        self.reload()
        return GLib.SOURCE_REMOVE

    @Property(bool, default_value=False)
    def style_changed(self) -> bool:
        return self._style_changed

    def reload(self, *_):
        try:
            resolved_css = compile_resolved_stylesheet()
            if resolved_css:
                target_style = resolve_style_file("style.css")
                base_dir = os.path.dirname(target_style) if os.path.isfile(target_style) else "."
                self.app.set_stylesheet_from_string(
                    style_string=resolved_css,
                    compile=True,
                    base_path=base_dir,
                )

            GLib.timeout_add(100, apply_plugin_css, self.app)

            self._style_changed = not self._style_changed
            self.notify("style-changed")

        except Exception as e:
            logger.error(f"[StyleService] Error reloading styles: {e}")
