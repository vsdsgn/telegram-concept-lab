#!/usr/bin/env python3
"""One-prompt, two-platform local launcher. Python standard library only."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import signal
import sys

ROOT = Path(__file__).resolve().parent
STATE = ROOT / ".lab"
CONCEPTS = ROOT / "concepts"

def run(cmd, cwd=ROOT, check=True):
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=check)

def valid_slug(s):
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,49}", s):
        raise SystemExit("Concept slug must be 3-50 lowercase letters, numbers, hyphens.")
    return s

def doctor():
    missing = []
    checks = {
        "git": ["git", "--version"],
        "github": ["gh", "auth", "status"],
        "codex": ["codex", "login", "status"],
        "claude": ["claude", "auth", "status"],
        "xcode": ["xcodebuild", "-version"],
    }
    for name, cmd in checks.items():
        try:
            result = run(cmd, check=False)
            okay = result.returncode == 0
        except (FileNotFoundError, OSError):
            okay = False
        print(f"{name:16} {'OK' if okay else 'MISSING OR UNAUTHENTICATED'}")
        if not okay:
            missing.append(name)
    for name, path in {
        "android sdk": Path.home() / "Library/Android/sdk",
        "adb": Path.home() / "Library/Android/sdk/platform-tools/adb",
        "emulator": Path.home() / "Library/Android/sdk/emulator/emulator",
        "Android Studio": Path("/Applications/Android Studio.app"),
        "JDK 17": Path("/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java"),
        "isolated Codex": Path.home() / ".local/share/telegram-concept-lab/codex-home/config.toml",
        "Concept Lab.app": Path.home() / "Applications/Telegram Concept Lab.app",
    }.items():
        okay = path.exists()
        print(f"{name:16} {'OK' if okay else 'MISSING'}")
        if not okay:
            missing.append(name)
    if missing:
        raise SystemExit("Prerequisites missing: " + ", ".join(missing))


def registry():
    STATE.mkdir(exist_ok=True)
    p = STATE / "jobs.json"
    return json.loads(p.read_text()) if p.exists() else {}

def save(jobs):
    (STATE / "jobs.json").write_text(json.dumps(jobs, indent=2))

def new(slug, prompt, swap=False, demo=False):
    if swap:
        raise SystemExit("--swap is retired: roles are shared across BOTH platforms.")
    if not demo:
        raise SystemExit("This command creates a standalone MOCK, not Telegram. Specify --demo explicitly.")
    import collab
    collab.create(slug, prompt)

def worker(slug, platform, agent, instruction):
    jobs = registry()
    job = jobs[slug]["platforms"][platform]
    cwd = Path(job["worktree"])
    if agent == "codex":
        cmd = ["codex", "exec", "-C", str(cwd), "-m", "gpt-5.6-sol", "--approve-for-me", instruction]
    else:
        cmd = ["claude", "-p", "--model", "sonnet", "--permission-mode", "auto",
               "--settings", '{"env":{"ANTHROPIC_BASE_URL":"","ANTHROPIC_API_KEY":"","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY":"false"}}', instruction]
    env = os.environ.copy()
    if agent == "claude":
        for key in ("ANTHROPIC_AUTH_TOKEN", "AI_GATEWAY_API_KEY"):
            env.pop(key, None)
    print(f"Starting {agent} for {platform}", flush=True)
    try:
        outcome = subprocess.run(cmd, cwd=cwd, stdin=subprocess.DEVNULL, env=env, timeout=3600)
        code = outcome.returncode
    except subprocess.TimeoutExpired:
        code = 124
        print("Worker time limit reached", flush=True)
    except Exception as e:
        code = 125
        print(f"Worker error: {e}", flush=True)
    proof = STATE / "logs" / slug / f"{platform}.exit"
    proof.write_text(str(code))
    print(f"Worker exit status: {code}", flush=True)
    return code

def status():
    jobs = registry()
    if not jobs:
        print("No jobs yet.")
    for slug, data in jobs.items():
        if data.get("mode") == "collaborative":
            import collab
            collab.print_status(slug, data)
            continue
        print(slug)
        for platform, job in data["platforms"].items():
            marker = STATE / "logs" / slug / f"{platform}.exit"
            state = "exit=" + marker.read_text().strip() if marker.exists() else "not yet completed / check logs"
            print(f"  {platform:8} {job['agent']:6} {state}  {job['branch']}")

def logs(slug, platform):
    valid_slug(slug)
    if registry().get(slug, {}).get("mode") == "collaborative":
        allowed = {"pipeline","design","design-review","design-revise","build-ios","build-android",
                   "review-ios","review-android","fix-ios","fix-android","verify-ios","verify-android"}
        if platform not in allowed: raise SystemExit(f"Use one of: {', '.join(sorted(allowed))}")
        p = STATE / "logs" / slug / (platform + ".log")
        print("".join(p.read_text(errors="replace").splitlines(keepends=True)[-80:]) if p.exists() else "Not started")
        return
    job = registry().get(slug, {}).get("platforms", {}).get(platform)
    if not job:
        raise SystemExit("Job not found")
    p = Path(job["log"])
    print("".join(p.read_text(errors="replace").splitlines(keepends=True)[-100:]) if p.exists() else "No log yet")

def prs(slug):
    valid_slug(slug)
    jobs = registry().get(slug)
    if not jobs:
        raise SystemExit("Concept not found.")
    if jobs.get("mode") == "collaborative":
        marker = STATE / "logs" / slug / "pipeline.exit"
        if not marker.exists() or marker.read_text().strip() != "0":
            raise SystemExit("The design-build-review-fix pipeline is not complete; do not publish PRs yet.")
        if any(not (STATE / "logs" / slug / f"verify-{p}.exit").exists()
               or (STATE / "logs" / slug / f"verify-{p}.exit").read_text().strip() != "0"
               for p in ("ios", "android")):
            raise SystemExit("Native Xcode and Gradle builds must pass independent verification before PRs.")
    for platform, job in jobs["platforms"].items():
        if not (STATE / "logs" / slug / f"{platform}.exit").exists():
            print(platform, "not finished; skip")
            continue
        worktree = Path(job["worktree"])
        run(["git", "push", "-u", "origin", job["branch"]], cwd=worktree)
        existing = run(["gh", "pr", "list", "--head", job["branch"], "--json", "url", "--jq", ".[0].url"], check=False)
        if existing.stdout.strip():
            print(existing.stdout.strip())
            continue
        pr = run(["gh", "pr", "create", "--draft", "--base", "main", "--head",
                  job["branch"], "--title", f"{slug}: {platform} implementation",
                  "--body", f"Code-first {platform} proof for {slug}. Please review build evidence before merge."],
                 cwd=worktree, check=False)
        print(platform, (pr.stdout or pr.stderr).strip())


def retry(slug):
    slug = valid_slug(slug)
    if registry().get(slug, {}).get("mode") == "collaborative":
        raise SystemExit("Collaborative run retries need stage-specific review; see logs before re-running.")
    jobs = registry()
    if slug not in jobs:
        raise SystemExit("Concept does not exist.")
    spec = (CONCEPTS / slug / "SPEC.md").read_text()
    prompt = spec.split("## User prompt", 1)[-1].split("## Shared behavior contract", 1)[0].strip()
    for platform, job in jobs[slug]["platforms"].items():
        marker = STATE / "logs" / slug / f"{platform}.exit"
        if not marker.exists():
            print(platform, "not marked finished; skip to avoid duplicate")
            continue
        if marker.read_text().strip() == "0":
            print(platform, "already successful; skip")
            continue
        marker.unlink()
        log = Path(job["log"])
        log.write_text("")
        instruction = (
            f"Implement the {platform.upper()} part of concept '{slug}'. "
            f"Read AGENTS.md, DESIGN.md and concepts/{slug}/SPEC.md first. "
            f"Work only under concepts/{slug}/{platform}/ in your worktree. "
            "Create a standalone runnable native app and README. Verify build using Xcode Simulator "
            "or Android Studio/SDK. No external publishing, pushing or merging. "
            "Use mock data and label it. Make a git commit of your implementation. "
            f"Original product request: {prompt}"
        )
        with log.open("a") as f:
            p = subprocess.Popen(
                [sys.executable, str(ROOT / "lab.py"), "worker", slug, platform, job["agent"], instruction],
                cwd=ROOT, stdout=f, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True
            )
        job["pid"] = p.pid
        save(jobs)
        print(platform, "restarted", "pid=", p.pid)

def pid_alive(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def stop(slug):
    slug = valid_slug(slug)
    jobs = registry()
    job = jobs.get(slug)
    if not job or job.get("mode") != "collaborative":
        raise SystemExit("Only collaborative jobs can be stopped.")
    if job.get("phase") in ("failed", "complete"):
        raise SystemExit("Job has already stopped.")
    pid = job.get("pid")
    if not pid_alive(pid):
        raise SystemExit("Job process is not alive; use resume instead.")
    if pid == os.getpid() or pid == os.getpgrp():
        raise SystemExit("Refusing to signal current shell.")
    # Every job starts in its own session. Stop the worker AND its model subprocesses.
    os.killpg(pid, signal.SIGTERM)
    job["phase"] = "failed"
    job["failed_step"] = "stopped"
    job["error"] = "Остановлено пользователем. Можно продолжить с сохранённых этапов."
    save(jobs)
    logs = STATE / "logs" / slug
    (logs / "pipeline.exit").write_text("1")
    with (logs / "pipeline.log").open("a") as f:
        f.write("\n[STOP] User requested cancellation\n")
    print(f"STOPPED {slug}")


def resume(slug):
    slug = valid_slug(slug)
    jobs = registry()
    job = jobs.get(slug)
    if not job or job.get("mode") != "collaborative":
        raise SystemExit("Only collaborative jobs can resume.")
    if job.get("phase") == "complete":
        raise SystemExit("Concept is complete; create draft PRs instead.")
    if job.get("phase") != "failed":
        if pid_alive(job.get("pid")):
            raise SystemExit("Concept is still running. Refusing a duplicate parallel run.")
        job["phase"] = "failed"
        job["error"] = "Предыдущий процесс прерван. Восстанавливаем."
        jobs[slug] = job
        save(jobs)
    log_dir = STATE / "logs" / slug
    (log_dir / "pipeline.exit").unlink(missing_ok=True)
    job["phase"] = "queued"
    job.pop("error", None)
    job.pop("failed_step", None)
    save(jobs)
    with (log_dir / "pipeline.log").open("a") as f:
        f.write("\n[RESUME] Restarting from first incomplete stage\n")
        p = subprocess.Popen(
            ["/usr/bin/caffeinate", "-i", sys.executable, str(ROOT / "collab.py"), "run", slug],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=f,
            stderr=subprocess.STDOUT, start_new_session=True,
        )
    jobs = registry()
    jobs[slug]["pid"] = p.pid
    save(jobs)
    print(f"RESUMED {slug} pid={p.pid}")

def main():
    ap = argparse.ArgumentParser()
    s = ap.add_subparsers(dest="command", required=True)
    s.add_parser("doctor")
    s.add_parser("workflow")
    n = s.add_parser("new")
    n.add_argument("slug")
    n.add_argument("prompt")
    n.add_argument("--swap", action="store_true")
    n.add_argument("--demo", action="store_true", help="Explicitly create a standalone mock")
    s.add_parser("status")
    verification = s.add_parser("verify")
    verification.add_argument("slug")
    preview_parser = s.add_parser("preview")
    preview_parser.add_argument("slug")
    preview_parser.add_argument("platform", choices=["ios", "android"])
    resume_parser = s.add_parser("resume")
    resume_parser.add_argument("slug")
    stop_parser = s.add_parser("stop")
    stop_parser.add_argument("slug")
    reparse = s.add_parser("retry")
    reparse.add_argument("slug")
    l = s.add_parser("logs")
    l.add_argument("slug")
    l.add_argument("platform", choices=["ios", "android", "pipeline", "design",
                                         "design-review", "design-revise", "build-ios", "build-android",
                                         "review-ios", "review-android", "fix-ios", "fix-android",
                                         "verify-ios", "verify-android"])
    p = s.add_parser("prs")
    p.add_argument("slug")
    w = s.add_parser("worker", help=argparse.SUPPRESS)
    w.add_argument("slug")
    w.add_argument("platform")
    w.add_argument("agent")
    w.add_argument("instruction")
    args = ap.parse_args()
    if args.command == "doctor":
        doctor()
    elif args.command == "workflow":
        import collab
        collab.show_workflow()
    elif args.command == "new":
        new(args.slug, args.prompt, args.swap, demo=args.demo)
    elif args.command == "status":
        status()
    elif args.command == "verify":
        import verify
        sys.exit(0 if verify.verify_all(valid_slug(args.slug)) else 1)
    elif args.command == "preview":
        import preview
        preview.preview(valid_slug(args.slug), args.platform)
    elif args.command == "resume":
        resume(args.slug)
    elif args.command == "stop":
        stop(args.slug)
    elif args.command == "retry":
        retry(args.slug)
    elif args.command == "logs":
        logs(args.slug, args.platform)
    elif args.command == "prs":
        prs(args.slug)
    elif args.command == "worker":
        sys.exit(worker(args.slug, args.platform, args.agent, args.instruction))

if __name__ == "__main__":
    main()
