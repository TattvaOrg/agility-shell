#!/usr/bin/env python3
"""
Settings reader with automatic migration and fallback for Agility Shell.
Checks ~/.config/agility-shell/settings_prefs.json first.
If missing, automatically migrates from ~/.cache/quickshell/settings_prefs.json.
Falls back to .bak files if primary is corrupted.
Prints valid JSON to stdout.
"""

import os
import sys
import json
import shutil

def try_load(path: str):
    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data
    except Exception:
        return None

def main():
    home = os.path.expanduser("~")
    primary_config = os.path.join(home, ".config", "agility-shell", "settings_prefs.json")
    primary_bak = primary_config + ".bak"
    cache_config = os.path.join(home, ".cache", "quickshell", "settings_prefs.json")
    cache_bak = cache_config + ".bak"

    data = None
    source = None

    # 1. Try primary durable config
    data = try_load(primary_config)
    if data is not None:
        source = "primary"

    # 2. If primary missing or corrupted, try primary .bak
    if data is None:
        data = try_load(primary_bak)
        if data is not None:
            source = "primary_bak"

    # 3. If still missing, check cache for initial automatic migration
    if data is None:
        data = try_load(cache_config)
        if data is not None:
            source = "cache_migration"
            try:
                os.makedirs(os.path.dirname(primary_config), exist_ok=True)
                with open(primary_config, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
            except Exception:
                pass

    # 4. If still missing, check cache .bak
    if data is None:
        data = try_load(cache_bak)
        if data is not None:
            source = "cache_bak"

    if data is not None:
        # Also ensure cache is in sync with primary
        if source in ("primary", "primary_bak") and not os.path.isfile(cache_config):
            try:
                os.makedirs(os.path.dirname(cache_config), exist_ok=True)
                shutil.copy2(primary_config, cache_config)
            except Exception:
                pass

        print(json.dumps(data))
        sys.exit(0)
    else:
        # No valid settings file found
        sys.exit(1)

if __name__ == "__main__":
    main()
