#!/usr/bin/env python3
"""
Atomic settings persister for Agility Shell.
Saves settings to ~/.config/agility-shell/settings_prefs.json (primary durable store),
mirrors to ~/.cache/quickshell/settings_prefs.json (runtime cache),
and syncs to /var/tmp/sddm-theme/settings_prefs.json (SDDM greeter theme) with .bak safeguards.
"""

import sys
import os
import json
import tempfile
import shutil

def atomic_write(filepath: str, data_str: str, make_backup: bool = True):
    target_dir = os.path.dirname(filepath)
    os.makedirs(target_dir, exist_ok=True)

    # If existing file is valid, create/update .bak
    if make_backup and os.path.isfile(filepath):
        try:
            if os.path.getsize(filepath) > 0:
                bak_path = filepath + ".bak"
                shutil.copy2(filepath, bak_path)
        except Exception:
            pass

    # Write to a temporary file in the same directory so os.replace is atomic (same filesystem)
    fd, tmp_path = tempfile.mkstemp(prefix="settings_", suffix=".tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data_str)
            f.flush()
            os.fsync(f.fileno())
        try:
            os.chmod(tmp_path, 0o644)
        except Exception:
            pass
        os.replace(tmp_path, filepath)
    except Exception as e:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
        raise e

def main():
    if len(sys.argv) < 2:
        print("Usage: save_settings.py '<json_string>'", file=sys.stderr)
        sys.exit(1)

    payload = sys.argv[1].strip()
    if not payload:
        print("Empty payload provided", file=sys.stderr)
        sys.exit(1)

    # Validate that payload is valid JSON before writing anything
    try:
        parsed = json.loads(payload)
        formatted_json = json.dumps(parsed, indent=2, ensure_ascii=False)
    except Exception as err:
        print(f"Error parsing JSON payload: {err}", file=sys.stderr)
        sys.exit(1)

    home = os.path.expanduser("~")
    primary_config = os.path.join(home, ".config", "agility-shell", "settings_prefs.json")
    cache_config = os.path.join(home, ".cache", "quickshell", "settings_prefs.json")
    sddm_config = "/var/tmp/sddm-theme/settings_prefs.json"

    # 1. Primary durable write
    try:
        atomic_write(primary_config, formatted_json, make_backup=True)
    except Exception as e:
        print(f"Warning: Failed to write to {primary_config}: {e}", file=sys.stderr)

    # 2. Cache mirror write
    try:
        atomic_write(cache_config, formatted_json, make_backup=True)
    except Exception as e:
        print(f"Warning: Failed to write to {cache_config}: {e}", file=sys.stderr)

    # 3. SDDM theme mirror write (optional/best-effort)
    try:
        os.makedirs(os.path.dirname(sddm_config), exist_ok=True)
        atomic_write(sddm_config, formatted_json, make_backup=False)
        try:
            os.chmod(sddm_config, 0o666)
        except Exception:
            pass
    except Exception:
        pass

    sys.exit(0)

if __name__ == "__main__":
    main()
