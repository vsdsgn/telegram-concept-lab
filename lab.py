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
    checks = {
        "git": ["git", "--version"],
        "github": ["gh", "auth", "status"],
        "codex": ["codex", "login", "status"],
        "claude": ["claude", "auth", "status"],
        "xcode": ["xcodebuild", "-version"],
    }
    for name, cmd in checks.items():
        try:
            r = run(cmd, check=False)
            print(f"{name:12} {'OK' if r.returncode == 0 else 'CHECK'}")
        except FileNotFoundError:
            print(f"{name:12} MISSING")
    for name, p in {
        "android sdk": Path.home() / "Library/Android/sdk",
        "adb": Path.home() / "Library/Android/sdk/platform-tools/adb",
        "emulator": Path.home() / "Library/Android/sdk/emulator/emulator",
        "Android Studio": Path("/Applications/Android Studio.app"),
    }.items():
        print(f"{name:12} {'OK' if p.exists() else 'MISSING'}")

def registry():
    STATE.mkdir(exist_ok=True)
    p = STATE / "jobs.json"
    return json.loads(p.read_text()) if p.exists() else {}

def save(jobs):
    (STATE / "jobs.json").write_text(json.dumps(jobs, indent=2))

def new(slug, prompt, swap=False):
    slug = valid_slug(slug)
    if slug in registry() or (CONCEPTS / slug).exists():
        raise SystemExit("Concept exists; choose a new slug for another run.")
    if run(["git", "status", "--porcelain"]).stdout.strip():
        raise SystemExit("Commit existing changes first (git status is dirty).")
    spec = CONCEPTS / slug / "SPEC.md"
    spec.parent.mkdir(parents=True, exist_ok=True)
    spec.write_text(
        f"# {slug}\n\n## User prompt\n{prompt}\n\n"
        "## Shared behavior contract\n"
        "Implement functionally equivalent interactions on iOS and Android. "
        "Define gesture states, completion/cancellation, accessible alternatives, and realistic animation. "
        "No invented Telegram APIs. Independent runnable app is allowed.\n\n"
        "## Acceptance\n- Native runnable demo on iOS and Android\n"
        "- Build commands and results documented\n- Screenshots/video instructions\n"
        "- No secret or private data\n"
    )
    run(["git", "add", f"concepts/{slug}/SPEC.md"])
    run(["git", "commit", "-m", f"spec: {slug} shared behavior contract"])
    run(["git", "push", "origin", "main"])
    jobs = registry()
    stamp = dt.datetime.now(dt.timezone.utc).isoformat()
    jobs[slug] = {"created_at": stamp, "platforms": {}}
    for platform, agent in [
        ("ios", "claude" if swap else "codex"),
        ("android", "codex" if swap else "claude"),
    ]:
        branch = f"concept/{slug}/{platform}"
        worktree = STATE / "worktrees" / slug / platform
        worktree.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "worktree", "add", "-b", branch, str(worktree), "main"])
        log = STATE / "logs" / slug / f"{platform}.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        instruction = (
            f"Implement the {platform.upper()} part of concept '{slug}'. "
            f"First read AGENTS.md, DESIGN.md and concepts/{slug}/SPEC.md. "
            f"Work ONLY in concepts/{slug}/{platform}/; create a standalone runnable native project "
            "and README with setup, build, run and test proof. "
            "Use installed Xcode/Simulator for iOS or Android Studio SDK/emulator for Android. "
            "Install only free missing dependencies necessary for build, no system-wide destructive changes. "
            "Use mock data and explicitly label it. Keep behavior consistent with shared SPEC.md. "
            "Do not touch the other platform. Do not push, publish, or merge. "
            "Make a git commit when finished. Report real build command/outcome. "
            f"Original product request: {prompt}"
        )
        job = {
            "agent": agent, "branch": branch, "worktree": str(worktree),
            "log": str(log), "started_at": stamp,
        }
        jobs[slug]["platforms"][platform] = job
        save(jobs)
        cmd = [
            sys.executable, str(ROOT / "lab.py"), "worker",
            slug, platform, agent, instruction,
        ]
        with log.open("a") as f:
            p = subprocess.Popen(cmd, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, start_new_session=True)
        job["pid"] = p.pid
        save(jobs)
        print(f"{platform:8} {agent:6} pid={p.pid} branch={branch}")
    print("Both workers launched. Check: python3 lab.py status")

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
        print(slug)
        for platform, job in data["platforms"].items():
            marker = STATE / "logs" / slug / f"{platform}.exit"
            state = "exit=" + marker.read_text().strip() if marker.exists() else "not yet completed / check logs"
            print(f"  {platform:8} {job['agent']:6} {state}  {job['branch']}")

def logs(slug, platform):
    valid_slug(slug)
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

def main():
    ap = argparse.ArgumentParser()
    s = ap.add_subparsers(dest="command", required=True)
    s.add_parser("doctor")
    n = s.add_parser("new")
    n.add_argument("slug")
    n.add_argument("prompt")
    n.add_argument("--swap", action="store_true")
    s.add_parser("status")
    reparse = s.add_parser("retry")
    reparse.add_argument("slug")
    l = s.add_parser("logs")
    l.add_argument("slug")
    l.add_argument("platform", choices=["ios", "android"])
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
    elif args.command == "new":
        new(args.slug, args.prompt, args.swap)
    elif args.command == "status":
        status()
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
