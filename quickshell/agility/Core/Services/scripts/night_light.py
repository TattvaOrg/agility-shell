#!/usr/bin/env python3
import sys
import shutil
import subprocess

def apply_night_light(temp):
    subprocess.run(["pkill", "-x", "wlsunset"], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-x", "gammastep"], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-x", "hyprsunset"], stderr=subprocess.DEVNULL)

    if shutil.which("wlsunset"):
        subprocess.Popen(["wlsunset", "-t", str(temp), "-T", "6500", "-s", "00:00", "-S", "00:01"])
        return
    if shutil.which("gammastep"):
        subprocess.Popen(["gammastep", "-O", str(temp)])
        return
    if shutil.which("hyprsunset"):
        subprocess.Popen(["hyprsunset", "-t", str(temp)])
        return

    subprocess.run(["notify-send", "-a", "Agility Shell", "Night Light", "Please install wlsunset or gammastep (e.g. sudo pacman -S wlsunset)"])

def revert_night_light():
    subprocess.run(["pkill", "-x", "wlsunset"], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-x", "gammastep"], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-x", "hyprsunset"], stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "revert":
        revert_night_light()
    else:
        temp = sys.argv[1] if len(sys.argv) > 1 else "4500"
        apply_night_light(temp)
