import os
import sys
import shutil
import signal
from loguru import logger

from services.paths import (
    get_user_config_dir,
    get_config_path,
    get_suits_config_path,
    get_user_state_dir,
    resolve_style_file,
    get_user_style_dir,
    get_search_data_dirs,
)

def _on_signal(*_):
    sys.exit(0)

signal.signal(signal.SIGTERM, _on_signal)
signal.signal(signal.SIGINT, _on_signal)

# Configure clean production logging (INFO default, DEBUG with AGILITY_DEBUG=1 or --debug)
log_level = "DEBUG" if os.getenv("AGILITY_DEBUG", "").lower() in ("1", "true", "yes") or "--debug" in sys.argv else "INFO"
logger.remove()
logger.add(sys.stderr, level=log_level, format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>")

def seed_user_environment():
    user_dir = get_user_config_dir()
    cfg_dir = os.path.join(user_dir, "config")
    custom_style_dir = get_user_style_dir()
    legacy_style_dir = os.path.join(user_dir, "style")
    state_dir = get_user_state_dir()

    # Fast-path: if environment is already initialized, skip redundant filesystem traversal
    if (
        os.path.isfile(os.path.join(cfg_dir, "config.json"))
        and os.path.isfile(os.path.join(custom_style_dir, "border.css"))
        and not os.path.exists(legacy_style_dir)
        and os.path.isdir(state_dir)
    ):
        return

    os.makedirs(cfg_dir, exist_ok=True)
    os.makedirs(custom_style_dir, exist_ok=True)
    os.makedirs(state_dir, exist_ok=True)

    # Migrate existing files from legacy style dir to custom_style dir if needed
    if os.path.isdir(legacy_style_dir):
        for fname in os.listdir(legacy_style_dir):
            src_f = os.path.join(legacy_style_dir, fname)
            dst_f = os.path.join(custom_style_dir, fname)
            if os.path.isfile(src_f) and not os.path.exists(dst_f):
                try:
                    shutil.copy2(src_f, dst_f)
                except Exception:
                    pass
        # Clean up legacy style dir to keep user config directory clean
        try:
            shutil.rmtree(legacy_style_dir)
        except Exception:
            pass

    # Ensure core configuration files are present
    get_config_path("config.json")
    get_suits_config_path()

    # Seed template custom_style files if missing
    for template_name in ["border.css", "font.css", "color.css", "README.md"]:
        target_path = os.path.join(custom_style_dir, template_name)
        if not os.path.exists(target_path):
            for base in get_search_data_dirs():
                src_candidate = os.path.join(base, "custom_style", template_name)
                if os.path.isfile(src_candidate):
                    try:
                        shutil.copy2(src_candidate, target_path)
                    except Exception:
                        pass
                    break

    # Clean up stale legacy component stylesheets in user custom_style dir that shadow updated system stylesheets
    whitelist = {
        "borders.css", "border.css",
        "fonts.css", "font.css",
        "colors.css", "color.css",
        "agility-shell-colors.css",
        "custom.css", "style.css",
        "README.md",
    }
    if os.path.isdir(custom_style_dir):
        # Remove legacy plural duplicates if standard singular user templates are present
        if os.path.isfile(os.path.join(custom_style_dir, "border.css")) and os.path.isfile(os.path.join(custom_style_dir, "borders.css")):
            try:
                os.remove(os.path.join(custom_style_dir, "borders.css"))
            except Exception:
                pass
        if os.path.isfile(os.path.join(custom_style_dir, "font.css")) and os.path.isfile(os.path.join(custom_style_dir, "fonts.css")):
            try:
                os.remove(os.path.join(custom_style_dir, "fonts.css"))
            except Exception:
                pass

        for fname in os.listdir(custom_style_dir):
            if fname.endswith(".css") and fname not in whitelist and not fname.startswith("custom"):
                try:
                    os.remove(os.path.join(custom_style_dir, fname))
                except Exception:
                    pass

    # Migrate existing widget settings if needed
    user_settings = os.path.join(user_dir, "widget_settings.json")
    if not os.path.exists(user_settings):
        legacy_qs = os.path.expanduser("~/.config/quickshell/widget_settings.json")
        repo_dir = os.path.dirname(os.path.abspath(__file__))
        default_qs = os.path.join(repo_dir, "quickshell", "agility", "widget_settings.json")
        src_settings = legacy_qs if os.path.exists(legacy_qs) else default_qs
        if os.path.exists(src_settings):
            try:
                shutil.copy2(src_settings, user_settings)
            except Exception:
                pass

seed_user_environment()

import utils.fabric_compat
import bar
import services.singletons as singletons
from setproctitle import setproctitle
from fabric import Application
from services.wallpaper import WallpaperService
from services.style import StyleService
from services.awe_service import AweService
from utils.sounds import play_sound
setproctitle("agility-shell")

app = Application("agility-shell")

singletons.style_service = StyleService(app)

singletons.style_service.reload()

bar_manager = bar.initialise_bars()
singletons.bar_manager = bar_manager

wallpaper_service = WallpaperService.get_instance()
# wallpaper_service.set_bar_manager(bar_manager)

from gi.repository import GLib
from services.suits_service import SuitsService, suits_service
profile_service = singletons.profile_service

def _post_startup():
    try:
        singletons.idle.start()
    except Exception as e:
        logger.warning(f"Failed to start idle service: {e}")
    try:
        AweService.get_instance().init_startup()
    except Exception as e:
        logger.warning(f"Failed to start AweService: {e}")
    try:
        play_sound("session-start")
    except Exception as e:
        logger.warning(f"Failed to play session-start sound: {e}")
    return False

GLib.idle_add(_post_startup)
app.run()