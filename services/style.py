import os
import re
from fabric.core.service import Service, Property
from fabric.utils import monitor_file
from gi.repository import GLib
from loguru import logger
from plugin_loader import apply_plugin_css
from services.paths import (
    get_user_config_dir,
    get_repo_dir,
    resolve_style_file,
    get_user_style_dirs,
    get_user_style_dir,
    get_system_style_file,
)
from services.fonts import font_service


def compile_border_css(content: str) -> str:
    """
    Compiles custom border CSS.
    Strips comments and converts CSS variables (e.g. --radius-m: 12px;) to @define constants.
    Removes :root / :vars wrappers to ensure GTK CSS compatibility.
    """
    clean = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    if not clean.strip():
        return ""

    added = []
    existing = set(re.findall(r'@define\s+([a-zA-Z0-9_-]+)', clean))
    var_matches = re.findall(r'--([a-zA-Z0-9_-]+)\s*:\s*([^;]+);', clean)
    for k, v in var_matches:
        if k not in existing and (k.startswith('radius') or 'radius' in k):
            added.append(f"@define {k} {v.strip()};")

    sanitized = re.sub(r':(?:root|vars)\s*\{[^}]*\}', '', clean)
    sanitized = re.sub(r'--[a-zA-Z0-9_-]+\s*:\s*[^;]+;', '', sanitized)

    parts = []
    if added:
        parts.extend(added)
    if sanitized.strip():
        parts.append(sanitized.strip())

    return "\n".join(parts)


def compile_color_css(content: str) -> str:
    """
    Compiles custom color CSS.
    Strips comments and converts CSS variables (e.g. --primary: #bb9af7;) to @define-color.
    Removes :root / :vars wrappers to ensure GTK CSS compatibility.
    """
    clean = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    if not clean.strip():
        return ""

    added = []
    existing = set(re.findall(r'@define-color\s+([a-zA-Z0-9_-]+)', clean))
    var_matches = re.findall(r'--([a-zA-Z0-9_-]+)\s*:\s*([^;]+);', clean)
    for k, v in var_matches:
        if k not in existing and not k.startswith('radius'):
            added.append(f"@define-color {k} {v.strip()};")

    sanitized = re.sub(r':(?:root|vars)\s*\{[^}]*\}', '', clean)
    sanitized = re.sub(r'--[a-zA-Z0-9_-]+\s*:\s*([^;]+);', '', sanitized)

    parts = []
    if added:
        parts.extend(added)
    if sanitized.strip():
        parts.append(sanitized.strip())

    return "\n".join(parts)


def compile_resolved_stylesheet(reload_callback=None) -> str | None:
    """
    Loads style.css and resolves every @import "<file>".
    Ensures user overrides in ~/.config/agility-shell/custom_style/ (such as user border.css,
    color.css, font.css) take precedence over static repo defaults while ALWAYS including
    system defaults (borders.css, Matugen colors.css, fonts.css) as baselines.
    Also compiles user font definitions (including automatic Google Fonts download & registration)
    and appends custom.css if present in the user style directory.
    """
    target_style = resolve_style_file("style.css")
    if not os.path.isfile(target_style):
        return None

    try:
        with open(target_style, "r") as f:
            content = f.read()

        def _replace_import(match: re.Match) -> str:
            fname = match.group(1).strip()
            if fname in ("fonts.css", "font.css"):
                compiled_fonts = font_service.get_compiled_font_css(on_installed=reload_callback)
                return f"\n/* --- Font Definitions --- */\n{compiled_fonts}\n"

            if fname in ("borders.css", "border.css"):
                # 1. Base system borders
                base_border_file = get_system_style_file("borders.css")
                base_border_css = ""
                if base_border_file and os.path.isfile(base_border_file):
                    try:
                        with open(base_border_file, "r") as bf:
                            base_border_css = bf.read()
                    except Exception as be:
                        logger.warning(f"[StyleService] Error reading base border file: {be}")

                # 2. User border overrides
                user_border_file = None
                for sdir in get_user_style_dirs():
                    for bname in ["border.css", "borders.css"]:
                        p = os.path.join(sdir, bname)
                        if os.path.isfile(p) and (not base_border_file or os.path.abspath(p) != os.path.abspath(base_border_file)):
                            user_border_file = p
                            break
                    if user_border_file:
                        break

                user_border_css = ""
                if user_border_file and os.path.isfile(user_border_file):
                    try:
                        with open(user_border_file, "r") as ubf:
                            user_border_css = compile_border_css(ubf.read())
                    except Exception as ube:
                        logger.warning(f"[StyleService] Error reading user border file {user_border_file}: {ube}")

                combined = base_border_css.strip()
                if user_border_css.strip():
                    combined += "\n" + user_border_css.strip()
                return f"\n/* --- Border Definitions --- */\n{combined}\n"

            if fname in ("colors.css", "color.css"):
                # 1. Active Matugen generated colors (or system fallback)
                matugen_color_file = None
                for sdir in get_user_style_dirs():
                    p = os.path.join(sdir, "colors.css")
                    if os.path.isfile(p):
                        matugen_color_file = p
                        break
                if not matugen_color_file:
                    matugen_color_file = get_system_style_file("colors.css")

                base_color_css = ""
                if matugen_color_file and os.path.isfile(matugen_color_file):
                    try:
                        with open(matugen_color_file, "r") as cf:
                            base_color_css = cf.read()
                    except Exception as ce:
                        logger.warning(f"[StyleService] Error reading matugen color file: {ce}")

                # 2. User custom color overrides
                user_color_file = None
                for sdir in get_user_style_dirs():
                    p = os.path.join(sdir, "color.css")
                    if os.path.isfile(p):
                        user_color_file = p
                        break

                user_color_css = ""
                if user_color_file and os.path.isfile(user_color_file):
                    try:
                        with open(user_color_file, "r") as ucf:
                            user_color_css = compile_color_css(ucf.read())
                    except Exception as uce:
                        logger.warning(f"[StyleService] Error reading user color file {user_color_file}: {uce}")

                combined = base_color_css.strip()
                if user_color_css.strip():
                    combined += "\n" + user_color_css.strip()
                return f"\n/* --- Color Definitions --- */\n{combined}\n"

            resolved = resolve_style_file(fname)
            if os.path.isfile(resolved):
                return f'@import "{resolved}";'
            return match.group(0)

        resolved_css = re.sub(r'@import\s+(?:url\()?["\']?([^"\')]+)["\']?\)?\s*;', _replace_import, content)

        user_custom = None
        for sdir in get_user_style_dirs():
            candidate = os.path.join(sdir, "custom.css")
            if os.path.isfile(candidate):
                user_custom = candidate
                break

        if user_custom and os.path.isfile(user_custom):
            try:
                with open(user_custom, "r") as uf:
                    custom_content = uf.read()
                clean_custom = re.sub(r'/\*.*?\*/', '', custom_content, flags=re.DOTALL)
                if clean_custom.strip():
                    resolved_css += f"\n/* --- Custom Overrides ({user_custom}) --- */\n{custom_content}\n"
            except Exception as ue:
                logger.warning(f"[StyleService] Error reading custom stylesheet {user_custom}: {ue}")

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

        self._style_monitors = []
        for sdir in get_user_style_dirs():
            os.makedirs(sdir, exist_ok=True)
            try:
                mon = monitor_file(sdir)
                mon.connect("changed", self._on_style_file_changed)
                self._style_monitors.append(mon)
            except Exception as e:
                logger.debug(f"[StyleService] Monitor error for {sdir}: {e}")

        repo_style_dir = os.path.join(get_repo_dir(), "style")
        if os.path.isdir(repo_style_dir):
            try:
                repo_mon = monitor_file(repo_style_dir)
                repo_mon.connect("changed", self._on_style_file_changed)
                self._style_monitors.append(repo_mon)
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
            resolved_css = compile_resolved_stylesheet(reload_callback=self.reload)
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
