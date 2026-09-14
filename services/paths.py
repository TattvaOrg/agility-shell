import os
import sys
import shutil
from typing import List, Optional

def get_user_config_dir() -> str:
    """Returns ~/.config/agility-shell or $XDG_CONFIG_HOME/agility-shell."""
    xdg_config = os.getenv("XDG_CONFIG_HOME")
    if xdg_config:
        return os.path.join(xdg_config, "agility-shell")
    return os.path.expanduser("~/.config/agility-shell")

def get_user_data_dir() -> str:
    """Returns ~/.local/share/agility-shell or $XDG_DATA_HOME/agility-shell."""
    xdg_data = os.getenv("XDG_DATA_HOME")
    if xdg_data:
        return os.path.join(xdg_data, "agility-shell")
    return os.path.expanduser("~/.local/share/agility-shell")

def get_user_state_dir() -> str:
    """Returns ~/.local/state/agility-shell or $XDG_STATE_HOME/agility-shell."""
    xdg_state = os.getenv("XDG_STATE_HOME")
    if xdg_state:
        return os.path.join(xdg_state, "agility-shell")
    return os.path.expanduser("~/.local/state/agility-shell")

def get_user_cache_dir() -> str:
    """Returns ~/.cache/agility-shell or $XDG_CACHE_HOME/agility-shell."""
    xdg_cache = os.getenv("XDG_CACHE_HOME")
    if xdg_cache:
        return os.path.join(xdg_cache, "agility-shell")
    return os.path.expanduser("~/.cache/agility-shell")

def get_repo_dir() -> str:
    """Returns the directory containing main.py (the running agility-shell code tree)."""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get_system_data_dirs() -> List[str]:
    """Returns system data directory candidates for agility-shell."""
    dirs: List[str] = []
    env_dirs = os.getenv("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    for d in env_dirs:
        if d:
            dirs.append(os.path.join(d, "agility-shell"))
    for standard in ["/usr/share/agility-shell", "/usr/local/share/agility-shell"]:
        if standard not in dirs:
            dirs.append(standard)
    return dirs

def get_search_data_dirs() -> List[str]:
    """
    Returns search directories in priority order:
    1. User custom overrides (~/.config/agility-shell)
    2. User data (~/.local/share/agility-shell)
    3. Current execution repo dir (e.g. git checkout or /usr/share/agility-shell)
    4. System data dirs (/usr/share/agility-shell, /usr/local/share/agility-shell)
    """
    candidates = [
        get_user_config_dir(),
        get_user_data_dir(),
        get_repo_dir(),
    ] + get_system_data_dirs()

    seen = set()
    result = []
    for c in candidates:
        if c and c not in seen:
            seen.add(c)
            result.append(c)
    return result

def resolve_asset(rel_path: str) -> str:
    """
    Finds the first existing file for a relative path across search data directories.
    Falls back to repo_dir/rel_path if not found.
    """
    for base in get_search_data_dirs():
        full = os.path.join(base, rel_path)
        if os.path.exists(full):
            return full
    return os.path.join(get_repo_dir(), rel_path)

def get_config_path(filename: str = "config.json") -> str:
    """
    Gets path to a user configuration file in ~/.config/agility-shell/config/<filename>.
    If it doesn't exist, seeds from system defaults.
    """
    cfg_dir = os.path.join(get_user_config_dir(), "config")
    os.makedirs(cfg_dir, exist_ok=True)
    target = os.path.join(cfg_dir, filename)

    if not os.path.exists(target):
        for base in [get_repo_dir()] + get_system_data_dirs():
            candidate = os.path.join(base, "config", filename)
            if os.path.exists(candidate):
                try:
                    shutil.copy2(candidate, target)
                except Exception:
                    pass
                break
    return target

def get_suits_config_path() -> str:
    """Returns the suits.json configuration file path."""
    return get_config_path("suits.json")

def get_state_path(filename: str) -> str:
    """
    Gets path to a runtime mutable state file in ~/.local/state/agility-shell/<filename>.
    Automatically checks legacy config directory and migrates existing files if found.
    """
    state_dir = get_user_state_dir()
    os.makedirs(state_dir, exist_ok=True)
    state_file = os.path.join(state_dir, filename)

    if not os.path.exists(state_file):
        legacy_candidates = [
            os.path.join(get_user_config_dir(), "config", filename),
            os.path.join(get_user_config_dir(), filename),
        ]
        for src in legacy_candidates:
            if os.path.exists(src):
                try:
                    shutil.copy2(src, state_file)
                except Exception:
                    pass
                break
    return state_file

def get_cache_path(filename: str) -> str:
    """Gets path to a cache or log file in ~/.cache/agility-shell/<filename>."""
    cache_dir = get_user_cache_dir()
    os.makedirs(cache_dir, exist_ok=True)
    return os.path.join(cache_dir, filename)

def get_wallpaper_dirs() -> List[str]:
    """Returns list of existing directories containing wallpapers (user custom + system stock)."""
    candidates = [
        os.path.join(get_user_config_dir(), "wallpapers"),
        os.path.join(get_user_data_dir(), "wallpapers"),
        os.path.join(get_repo_dir(), "wallpapers"),
    ] + [os.path.join(d, "wallpapers") for d in get_system_data_dirs()]

    dirs: List[str] = []
    seen = set()
    for d in candidates:
        if os.path.isdir(d) and d not in seen:
            seen.add(d)
            dirs.append(d)
    return dirs

def get_theme_dirs() -> List[str]:
    """Returns list of existing directories containing themes (user custom + system stock)."""
    candidates = [
        os.path.join(get_user_config_dir(), "themes"),
        os.path.join(get_user_data_dir(), "themes"),
        os.path.join(get_repo_dir(), "themes"),
    ] + [os.path.join(d, "themes") for d in get_system_data_dirs()]

    dirs: List[str] = []
    seen = set()
    for d in candidates:
        if os.path.isdir(d) and d not in seen:
            seen.add(d)
            dirs.append(d)
    return dirs

def resolve_theme_file(theme_filename: str) -> Optional[str]:
    """Finds a specific theme file across user and system theme directories."""
    for d in get_theme_dirs():
        p = os.path.join(d, theme_filename)
        if os.path.isfile(p):
            return p
    return None

def resolve_style_file(filename: str) -> str:
    """Resolves a stylesheet file checking user override first, then system defaults."""
    for base in get_search_data_dirs():
        p = os.path.join(base, "style", filename)
        if os.path.exists(p):
            return p
    return os.path.join(get_repo_dir(), "style", filename)

def get_native_lib_path(lib_name: str, snippet_name: str) -> str:
    """
    Resolves a compiled native shared library (.so).
    Prioritizes /usr/lib/agility-shell, then in-tree snippet lib directory.
    """
    candidates = [
        f"/usr/lib/agility-shell/{lib_name}",
        f"/usr/lib/agility-shell/lib/{lib_name}",
        f"/usr/local/lib/agility-shell/{lib_name}",
        os.path.join(get_repo_dir(), "snippets", snippet_name, "lib", lib_name),
        os.path.join("/usr/share/agility-shell", "snippets", snippet_name, "lib", lib_name),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return candidates[3]
