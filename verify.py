#!/usr/bin/env python3
"""Independent native build verification for both Telegram Concept Lab platforms."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
STATE = ROOT / ".lab"
JDK17 = Path("/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home")
SDK = Path.home() / "Library/Android/sdk"


def _run(cmd, cwd, logfile, env=None, timeout=900):
    logfile.parent.mkdir(parents=True, exist_ok=True)
    with logfile.open("a") as out:
        out.write("\n$ " + " ".join(map(str, cmd)) + "\n")
        out.flush()
        try:
            result = subprocess.run(
                [str(x) for x in cmd], cwd=str(cwd), env=env,
                stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT,
                timeout=timeout,
            )
            return result.returncode
        except subprocess.TimeoutExpired:
            out.write("\nTimeout while verifying native build\n")
            return 124
        except Exception as exc:
            out.write("\nBuild runner error: " + repr(exc) + "\n")
            return 125


def verify_one(slug, platform):
    if platform not in ("ios", "android"):
        raise ValueError("Platform must be ios or android")
    import collab
    collab.safe_slug(slug)
    work = STATE / "worktrees" / slug / platform / "concepts" / slug / platform
    log_dir = STATE / "logs" / slug
    log_dir.mkdir(parents=True, exist_ok=True)
    log = log_dir / f"verify-{platform}.log"
    proof = log_dir / f"verify-{platform}.exit"
    proof.unlink(missing_ok=True)
    log.write_text(f"Independent build verification for {slug} {platform}\n")

    if not work.is_dir():
        log.write_text(f"Missing native source directory {work}\n")
        proof.write_text("1")
        return False, "Native platform directory missing"
    if platform == "ios":
        projects = sorted(work.rglob("*.xcodeproj"))
        if not projects:
            log.write_text("No .xcodeproj found; cannot verify an iOS native app\n")
            proof.write_text("1")
            return False, "No Xcode project"
        project = projects[0]
        proc = subprocess.run(
            ["xcodebuild", "-list", "-json", "-project", str(project)],
            cwd=str(work), capture_output=True, text=True, timeout=120,
        )
        if proc.returncode:
            with log.open("a") as f:
                f.write("Unable to list Xcode schemes:\n" + proc.stderr[-3500:])
            proof.write_text("1")
            return False, "Xcode project invalid"
        try:
            data = json.loads(proc.stdout[proc.stdout.find("{"):])
            schemes = (data.get("project") or data.get("workspace") or {}).get("schemes", [])
        except (ValueError, TypeError):
            schemes = []
        scheme = schemes[0] if schemes else project.stem
        derived = STATE / "native-builds" / slug / "ios"
        cmd = [
            "xcodebuild", "-project", project, "-scheme", scheme,
            "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", derived,
            "CODE_SIGNING_ALLOWED=NO", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES",
            "build",
        ]
        result = _run(cmd, work, log, timeout=900)
        apps = list((derived / "Build/Products").rglob("*.app")) if derived.exists() else []
        if result == 0 and not apps:
            with log.open("a") as f:
                f.write("Build passed but no .app found in DerivedData\n")
            result = 1
    else:
        gradle = work / "gradlew"
        if not gradle.exists():
            log.write_text("Gradle wrapper missing. Add a reproducible gradlew and wrapper JAR.\n")
            proof.write_text("1")
            return False, "Gradle wrapper missing"
        if not (JDK17 / "bin/java").exists():
            log.write_text("JDK17 missing; use Homebrew openjdk@17.\n")
            proof.write_text("1")
            return False, "JDK17 missing"
        env = os.environ.copy()
        env["JAVA_HOME"] = str(JDK17)
        env["JAVA_TOOL_OPTIONS"] = env.get("JAVA_TOOL_OPTIONS", "")
        env["PATH"] = str(JDK17 / "bin") + os.pathsep + env.get("PATH", "")
        env["ANDROID_HOME"] = str(SDK)
        env["ANDROID_SDK_ROOT"] = str(SDK)
        result = _run(
            ["/bin/bash", str(gradle), "assembleDebug", "testDebugUnitTest", "--offline"],
            work, log, env=env, timeout=900,
        )
        apks = list(work.rglob("build/outputs/apk/debug/*.apk"))
        if result == 0 and not apks:
            with log.open("a") as f:
                f.write("Gradle passed but no debug .apk found\n")
            result = 1
    proof.write_text(str(result))
    return result == 0, ("Build and tests passed" if result == 0 else f"Build failed: {log}")


def verify_all(slug):
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        results = dict(zip(("ios", "android"), executor.map(
            lambda p: verify_one(slug, p), ("ios", "android")
        )))
    for platform, (success, detail) in results.items():
        print(platform, "OK" if success else "FAILED", detail, flush=True)
    return all(success for success, _ in results.values())


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 verify.py <slug>")
        sys.exit(2)
    sys.exit(0 if verify_all(sys.argv[1]) else 1)
