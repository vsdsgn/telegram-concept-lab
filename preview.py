#!/usr/bin/env python3
"""One-click native simulator preview of previously verified concept builds."""
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
STATE = ROOT / ".lab"
ADB = Path.home() / "Library/Android/sdk/platform-tools/adb"
EMULATOR = Path.home() / "Library/Android/sdk/emulator/emulator"
def selected_xcode_apps():
    """Xcode 27 moved Simulator to Device Hub; resolve selected Xcode, not a hardcoded path."""
    result = call(["xcode-select", "-p"], timeout=10)
    developer = Path(result.stdout.strip()).resolve()
    hub = developer.parent / "Applications/DeviceHub.app"
    legacy = developer / "Applications/Simulator.app"
    return hub, legacy


def reveal_ios_device(device):
    hub, legacy = selected_xcode_apps()
    if hub.is_dir():
        # Xcode 27 requires its Device Hub deep link, after the simulator has booted.
        uri = f"devices://device/open?id={device}"
        call(["open", "-a", hub, uri], timeout=25)
        return "Device Hub"
    if legacy.is_dir():
        call(["open", "-a", legacy, "--args", "-CurrentDeviceUDID", device], timeout=25)
        return "Simulator"
    return None


def reveal_android_window():
    """Focus the existing emulator GUI; without this the APK launches offscreen."""
    try:
        result = call(
            ["osascript", "-e",
             'tell application "System Events" to tell application process "qemu-system-aarch64" to set frontmost to true'],
            timeout=8, check=False,
        )
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def call(argv, timeout=90, check=True, capture=True):
    res = subprocess.run([str(x) for x in argv], capture_output=capture,
                         text=True, timeout=timeout)
    if check and res.returncode != 0:
        raise RuntimeError(
            f"Command failed: {argv[0]} (exit {res.returncode})\n"
            + ((res.stderr or res.stdout or "")[-2200:])
        )
    return res


def booted_iphone():
    res = call(["xcrun", "simctl", "list", "-j", "devices", "booted"])
    data = json.loads(res.stdout)
    devices = [d for items in data.get("devices", {}).values()
               for d in items if d.get("state") == "Booted" and "iPhone" in d.get("name", "")]
    return devices[0].get("udid") if devices else None


def ensure_ios():
    device = booted_iphone()
    if device:
        return device
    data = json.loads(call(["xcrun", "simctl", "list", "-j", "devices", "available"]).stdout)
    devices = [d for items in data.get("devices", {}).values()
               for d in items if d.get("isAvailable") and "iPhone" in d.get("name", "")]
    if not devices:
        raise RuntimeError("No available iPhone Simulator. Install iOS runtime in Xcode.")
    device = devices[0]["udid"]
    call(["xcrun", "simctl", "boot", device], timeout=70)
    call(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=180)
    return device


def connected_android():
    result = call([ADB, "devices"], timeout=12)
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) > 1 and parts[1] == "device":
            return parts[0]
    return None


def ensure_android():
    existing = connected_android()
    if existing:
        return existing
    avds = call([EMULATOR, "-list-avds"], timeout=15).stdout.splitlines()
    target = "ds_android" if "ds_android" in avds else (avds[0] if avds else "")
    if not target:
        raise RuntimeError("No Android Virtual Device configured in Android Studio.")
    logs = STATE / "previews"
    logs.mkdir(parents=True, exist_ok=True)
    with (logs / "emulator.log").open("a") as out:
        subprocess.Popen(
            [str(EMULATOR), "-avd", target, "-no-snapshot-save", "-no-boot-anim"],
            stdout=out, stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL, start_new_session=True,
        )
    end = time.monotonic() + 160
    while time.monotonic() < end:
        time.sleep(3)
        try:
            device = connected_android()
            if device:
                status = call([ADB, "-s", device, "shell", "getprop", "sys.boot_completed"], timeout=8)
                if status.stdout.strip() == "1":
                    return device
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            continue
    raise RuntimeError("Android Emulator failed to boot within the timeout. Inspect .lab/previews/emulator.log.")


def android_id(gradle_path):
    content = gradle_path.read_text(encoding="utf-8")
    found = re.search(r'\bapplicationId\s*=\s*["\']([^"\']+)["\']', content)
    if not found:
        raise RuntimeError("Android applicationId missing from app/build.gradle.kts")
    return found.group(1)


def preview(slug, platform):
    import collab
    collab.safe_slug(slug)
    if platform not in ("ios", "android"):
        raise ValueError("platform must be ios or android")
    marker = STATE / "logs" / slug / f"verify-{platform}.exit"
    if not marker.exists() or marker.read_text().strip() != "0":
        raise RuntimeError(
            f"{platform} native build not verified. Open the concept and click Verify builds first."
        )
    screenshot_dir = STATE / "previews" / slug
    screenshot_dir.mkdir(parents=True, exist_ok=True)

    if platform == "ios":
        folder = STATE / "native-builds" / slug / "ios" / "Build/Products"
        apps = sorted(folder.glob("Debug-iphonesimulator/*.app"))
        if not apps:
            raise RuntimeError("No compiled iOS .app found in native build output.")
        app = apps[0]
        with (app / "Info.plist").open("rb") as fp:
            bundle_id = plistlib.load(fp).get("CFBundleIdentifier")
        if not bundle_id or "$(" in bundle_id:
            raise RuntimeError("iOS CFBundleIdentifier is invalid.")
        device = ensure_ios()
        call(["xcrun", "simctl", "install", device, app], timeout=130)
        call(["xcrun", "simctl", "launch", device, bundle_id], timeout=30)
        host = reveal_ios_device(device)
        time.sleep(2)
        screenshot = screenshot_dir / "ios.png"
        call(["xcrun", "simctl", "io", device, "screenshot", screenshot], timeout=30)
        print(f"iOS demo RUNNING on {device}\nScreenshot: {screenshot}")
        print(f"Window host: {host or 'unavailable'}. Screenshot is visible in Concept Lab.")
        if host == "Device Hub":
            print("Xcode 27 opens simulators through Device Hub, not Simulator.app.")
    else:
        work = STATE / "worktrees" / slug / "android" / "concepts" / slug / "android"
        apk = work / "app/build/outputs/apk/debug/app-debug.apk"
        gradle = work / "app/build.gradle.kts"
        if not apk.exists() or not gradle.exists():
            raise RuntimeError("Verified Android APK/Gradle file missing.")
        package = android_id(gradle)
        device = ensure_android()
        call([ADB, "-s", device, "install", "-r", apk], timeout=170)
        call([ADB, "-s", device, "shell", "am", "force-stop", package], timeout=20, check=False)
        call([ADB, "-s", device, "shell", "monkey", "-p", package,
              "-c", "android.intent.category.LAUNCHER", "1"], timeout=25)
        time.sleep(2)
        pid = call([ADB, "-s", device, "shell", "pidof", package], timeout=15)
        if not pid.stdout.strip():
            raise RuntimeError("Android app launch failed: process is not alive.")
        screenshot = screenshot_dir / "android.png"
        with screenshot.open("wb") as f:
            res = subprocess.run([str(ADB), "-s", device, "exec-out", "screencap", "-p"],
                                 stdout=f, stderr=subprocess.PIPE, timeout=30)
            if res.returncode:
                raise RuntimeError("Android screenshot failed.")
        focused = reveal_android_window()
        print(f"Android demo RUNNING on {device} (PID {pid.stdout.strip()})\nScreenshot: {screenshot}")
        print("Emulator window:", "focused" if focused else "focus unavailable; see screenshot in Concept Lab")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 preview.py <slug> ios|android")
        sys.exit(2)
    try:
        preview(sys.argv[1], sys.argv[2])
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"PREVIEW FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
