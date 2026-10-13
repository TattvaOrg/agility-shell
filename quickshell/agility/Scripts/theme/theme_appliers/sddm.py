import json
import os
import shutil
import subprocess

from color_utils import sanitize_color


def apply(home, colors):
    sddm_dir = "/var/tmp/sddm-theme"
    try:
        os.makedirs(sddm_dir, mode=0o777, exist_ok=True)
        try:
            os.chmod(sddm_dir, 0o777)
        except OSError:
            pass

        # Read font family from quickshell preferences if available
        font_family = "Geist"
        prefs_file = os.path.join(home, ".cache", "quickshell", "settings_prefs.json")
        if os.path.exists(prefs_file):
            try:
                with open(prefs_file, "r") as pf:
                    prefs_data = json.load(pf)
                    if prefs_data.get("fontFamily"):
                        font_family = prefs_data["fontFamily"]
            except Exception:
                pass

        # Prepare color map with sanitized hex colors
        theme_data = {
            "font": font_family,
            "name": "Dynamic Tokyo Night",
            "bg": sanitize_color(colors.get("bg", "#09080b")),
            "opaqueBg": sanitize_color(colors.get("opaqueBg", "#09080b")),
            "fg": sanitize_color(colors.get("fg", "#f1f0f4")),
            "muted": sanitize_color(colors.get("muted", "#66f1f0f4")),
            "border": sanitize_color(colors.get("border", "#1af1f0f4")),
            "accent": sanitize_color(colors.get("accent", "#8265cc")),
            "accentComplementary": sanitize_color(
                colors.get("accentComplementary", "#cc64c8")
            ),
            "overlayBase": sanitize_color(colors.get("overlayBase", "#a38fd8")),
            "bgSecondary": sanitize_color(colors.get("bgSecondary", "#0fa38fd8")),
            "bgTertiary": sanitize_color(colors.get("bgTertiary", "#05a38fd8")),
            "bgAccent": sanitize_color(colors.get("bgAccent", "#268265cc")),
            "bgAccentComplementary": sanitize_color(
                colors.get("bgAccentComplementary", "#26cc64c8")
            ),
            "shadow": sanitize_color(colors.get("shadow", "#bf000000")),
            "isDark": bool(colors.get("is_dark", True)),
        }

        colors_file = os.path.join(sddm_dir, "colorscheme.json")
        with open(colors_file, "w") as f:
            json.dump(theme_data, f, indent=2)
        try:
            os.chmod(colors_file, 0o666)
        except OSError:
            pass

        # Sync wallpaper
        qs_wall_file = os.path.join(home, ".cache", "quickshell", "current_wallpaper")
        if os.path.exists(qs_wall_file):
            with open(qs_wall_file, "r") as f:
                wall_name = f.read().strip()

            if wall_name:
                if wall_name.startswith("/"):
                    src_wall = wall_name
                else:
                    src_wall = os.path.join(home, "Pictures", "Wallpapers", wall_name)

                if os.path.exists(src_wall):
                    dest_wall_png = os.path.join(sddm_dir, "wallpaper.png")
                    ext = os.path.splitext(src_wall)[1].lower()
                    if ext in [".png", ".jpg", ".jpeg"]:
                        shutil.copyfile(src_wall, dest_wall_png)
                    else:
                        # For animated or non-standard formats (GIF, WebP, etc.), extract only the first frame
                        # Check if Quickshell already extracted a cached static frame
                        base_name = os.path.basename(src_wall)
                        cached_frame = os.path.join(
                            home, ".cache", "quickshell", "frames", base_name + ".jpg"
                        )
                        if os.path.exists(cached_frame):
                            shutil.copyfile(cached_frame, dest_wall_png)
                        else:
                            # Use magick with [0] to only decode the first frame and avoid memory explosion
                            res = subprocess.run(
                                ["magick", f"{src_wall}[0]", dest_wall_png],
                                capture_output=True,
                            )
                            if res.returncode != 0:
                                subprocess.run(
                                    [
                                        "ffmpeg",
                                        "-y",
                                        "-i",
                                        src_wall,
                                        "-vframes",
                                        "1",
                                        dest_wall_png,
                                    ],
                                    capture_output=True,
                                )

                    if os.path.exists(dest_wall_png):
                        try:
                            os.chmod(dest_wall_png, 0o666)
                        except OSError:
                            pass

                    name_file = os.path.join(sddm_dir, "current_wallpaper")
                    with open(name_file, "w") as f:
                        f.write(wall_name)
                    try:
                        os.chmod(name_file, 0o666)
                    except OSError:
                        pass
    except Exception as e:
        print(f"Error applying SDDM theme colors: {e}")
