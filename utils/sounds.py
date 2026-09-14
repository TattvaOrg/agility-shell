import shutil
from fabric.utils import exec_shell_command_async
from services.paths import resolve_asset

def _detect_player() -> str | None:
    for player in ("pw-play", "paplay"):
        if shutil.which(player):
            return player
    return None

def get_sound_path(name):
    return resolve_asset(f"sounds/{name}.wav")

_PLAYER = _detect_player()

def play_sound(name: str) -> None:
    if _PLAYER is None:
        return
    sound_file = get_sound_path(name)
    if sound_file:
        exec_shell_command_async(f"{_PLAYER} '{sound_file}'")