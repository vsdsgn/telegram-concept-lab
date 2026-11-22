#!/usr/bin/env python3
"""Collaborative concept pipeline: Claude UX -> Codex design QA -> Codex iOS+Android -> Claude code QA -> Codex fixes.

Only the public concept repo is modified. Models run in separate Git worktrees; no Paperclip
adapter, no unrestricted host agent, and no automatic merge or store publication.
"""
import concurrent.futures
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parent
STATE = ROOT / ".lab"
TASKS = STATE / "jobs.json"
SETTINGS = '{"env":{"ANTHROPIC_BASE_URL":"","ANTHROPIC_API_KEY":"","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY":"false"}}'
JOB_LOCK = threading.Lock()
PHASES = [
    ("design", "Claude: UX / interaction design"),
    ("design-review", "Codex: design critique"),
    ("design-revise", "Claude: design corrections"),
    ("build-ios", "Codex: iOS implementation"),
    ("build-android", "Codex: Android implementation"),
    ("review-ios", "Claude: iOS code review"),
    ("review-android", "Claude: Android code review"),
    ("fix-ios", "Codex: iOS fixes / design verification"),
    ("fix-android", "Codex: Android fixes / design verification"),
]

def git(*args, cwd=ROOT):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {result.stderr[-900:]}")
    return result.stdout.strip()

def get_jobs():
    return json.loads(TASKS.read_text()) if TASKS.exists() else {}

def save(jobs):
    STATE.mkdir(exist_ok=True)
    tmp = TASKS.with_suffix(".tmp")
    tmp.write_text(json.dumps(jobs, ensure_ascii=False, indent=2))
    tmp.replace(TASKS)

def update(slug, **fields):
    with JOB_LOCK:
        jobs = get_jobs()
        jobs[slug].update(fields)
        save(jobs)

def safe_slug(slug):
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,49}", slug):
        raise ValueError("Use a slug of 3-50 lowercase letters, numbers and hyphens")
    return slug

def create(slug, prompt):
    safe_slug(slug)
    if not prompt.strip():
        raise ValueError("Empty prompt")
    if slug in get_jobs() or (ROOT / "concepts" / slug).exists():
        raise ValueError("Concept already exists")
    if git("status", "--porcelain"):
        raise ValueError("Commit outstanding changes before starting a concept")
    spec = ROOT / "concepts" / slug / "SPEC.md"
    spec.parent.mkdir(parents=True, exist_ok=True)
    spec.write_text(
        f"# {slug}\n\n## Original user request\n\n{prompt}\n\n"
        "## Collaboration contract\n\n"
        "1. Claude produces concrete interaction design for iOS AND Android.\n"
        "2. Codex critiques the proposed UX and implements both native apps.\n"
        "3. Claude reviews BOTH codebases; Codex fixes issues and checks visual fidelity.\n"
        "4. Each platform runs and tests independently. No Telegram backend integration is assumed.\n"
        "5. The idea and code are PUBLIC; do not use secrets, sensitive or employer assets.\n"
    )
    git("add", f"concepts/{slug}/SPEC.md")
    git("commit", "-m", f"spec: {slug} collaborative pipeline")
    git("push", "origin", "main")
    worktrees = {}
    for part in ("design", "ios", "android"):
        branch = f"concept/{slug}/{part}"
        directory = STATE / "worktrees" / slug / part
        directory.parent.mkdir(parents=True, exist_ok=True)
        git("worktree", "add", "-b", branch, str(directory), "main")
        worktrees[part] = {"branch": branch, "worktree": str(directory)}
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    logs = STATE / "logs" / slug
    logs.mkdir(parents=True, exist_ok=True)
    jobs = get_jobs()
    jobs[slug] = {
        "mode": "collaborative", "phase": "queued", "created_at": now,
        "platforms": {
            platform: {**worktrees[platform], "agent": "codex", "log": str(logs / f"build-{platform}.log")}
            for platform in ("ios", "android")
        },
        "design": worktrees["design"],
    }
    save(jobs)
    with (logs / "pipeline.log").open("w") as f:
        proc = subprocess.Popen(
            [sys.executable, str(ROOT / "collab.py"), "run", slug],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=f,
            stderr=subprocess.STDOUT, start_new_session=True,
        )
    update(slug, pid=proc.pid)
    print(f"Started collaborative pipeline {slug} pid={proc.pid}")
    print("Claude designs BOTH platforms; Codex reviews design and builds BOTH platforms;")
    print("Claude code-reviews BOTH; Codex fixes BOTH. Draft PRs remain manual.")

def tool(agent, cwd, prompt, logfile, readonly=False, timeout=3600):
    env = os.environ.copy()
    if agent == "codex":
        # Workspace-write sandbox, never use --dangerously-bypass-approvals-and-sandbox.
        cmd = ["codex", "exec", "-C", str(cwd), "-m", "gpt-5.6-sol", "--approve-for-me", prompt]
    elif agent == "claude":
        for key in ("ANTHROPIC_AUTH_TOKEN", "AI_GATEWAY_API_KEY"):
            env.pop(key, None)
        # Review is intentionally read-only; capture text to log, then orchestrator writes report.
        cmd = ["claude", "-p", "--model", "sonnet",
               "--permission-mode", "plan" if readonly else "auto",
               "--settings", SETTINGS, prompt]
    else:
        raise ValueError(agent)
    logfile.parent.mkdir(parents=True, exist_ok=True)
    with logfile.open("w") as f:
        try:
            proc = subprocess.run(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                  stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
            code = proc.returncode
        except subprocess.TimeoutExpired:
            code = 124
            f.write("\n[PIPELINE] Step exceeded time limit.\n")
        except OSError as e:
            code = 125
            f.write(f"\n[PIPELINE] Process error: {e}\n")
    logfile.with_suffix(".exit").write_text(str(code))
    if code:
        raise RuntimeError(f"{agent} step failed with exit {code}: {logfile}")
    return logfile.read_text(errors="replace")

def stage(slug, name, agent, cwd, prompt, readonly=False, report=None):
    update(slug, phase=name)
    log = STATE / "logs" / slug / (name + ".log")
    print(f"[{slug}] {name}: {agent} ({cwd})", flush=True)
    result = tool(agent, cwd, prompt, log, readonly=readonly)
    if report is not None:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text("# Claude Code Review\n\n" + result[-25000:] + "\n")
        git("add", str(report.relative_to(cwd)), cwd=cwd)
        git("commit", "-m", f"review: {slug} {name}", cwd=cwd)
    return result

def platform_prompt(slug, platform):
    return (
        f"You are Codex, IMPLEMENTER for BOTH platforms; this step owns {platform.upper()} ONLY. "
        f"Read AGENTS.md, DESIGN.md, concepts/{slug}/SPEC.md, concepts/{slug}/UX_DESIGN.md "
        f"and concepts/{slug}/DESIGN_REVIEW.md. Implement the {platform.upper()} native runnable demo "
        f"ONLY under concepts/{slug}/{platform}/. iOS: Swift/UIKit, Xcode + Simulator; "
        "Android: Kotlin/Android SDK, Gradle + Emulator. Match Claude's shared interaction spec "
        "and address Codex's design critique; choose platform-native patterns without divergent behavior. "
        "Include gestures, cancellation, accessibility, dark mode, reduced motion, tests, and a README "
        "with the exact build command and verified result. Use explicitly labeled mock data. "
        "No source copying from private apps, pushing, merging, publishing, or modifying other projects. "
        "Make a Git commit of your own code. "
        "You are not delegated to change files for the other platform."
    )

def code_review_prompt(slug, platform):
    return (
        f"You are Claude, DESIGN OWNER and independent CODE REVIEWER. "
        f"Inspect native {platform.upper()} implementation under concepts/{slug}/{platform}/, "
        f"cross-check against concepts/{slug}/UX_DESIGN.md and concepts/{slug}/DESIGN_REVIEW.md. "
        "Do NOT edit any code or execute it. Produce a concise structured markdown review: "
        "P0 blockers, P1 bugs/security/performance/logic, UX fidelity, animation/accessibility, "
        "discrepancies with other platform's documented behavior, with paths and concrete fixes. "
        "Distinguish confirmed issues from guesses; state any missing build or runtime evidence. "
        "Do not invent test results. If no defects, explicitly say so."
    )

def run_pipeline(slug):
    safe_slug(slug)
    jobs = get_jobs()
    if jobs.get(slug, {}).get("mode") != "collaborative":
        raise ValueError(f"No collaborative concept {slug}")
    root = STATE / "worktrees" / slug
    design = root / "design"
    ios, android = root / "ios", root / "android"
    shared = f"concepts/{slug}"
    (STATE / "logs" / slug).mkdir(parents=True, exist_ok=True)
    try:
        stage(slug, "design", "claude", design,
              f"Act as a senior product interaction designer for Telegram UI. "
              f"Read AGENTS.md, DESIGN.md and {shared}/SPEC.md. "
              f"Design the concept FOR BOTH iOS AND ANDROID, not code-first. "
              f"Write {shared}/UX_DESIGN.md with: user problem, user journey, exact screens and "
              "states, gesture timelines, spring/motion parameters, token sizes, dark/light, "
              "accessibility, edge cases, native differences, and explicit cross-platform "
              "acceptance criteria. Optionally add concise text wireframes as markdown. "
              "No application implementation yet. Commit the design files. "
              "Use only public mock data and avoid private content.")
        stage(slug, "design-review", "codex", design,
              f"You are Codex, independent design critic before implementation. "
              f"Read {shared}/UX_DESIGN.md and DESIGN.md. Critically inspect interaction model, "
              "discoverability, transitions, reachability, destructive actions, native iOS/Android "
              "feasibility, performance, accessibility, and implementation risks. "
              f"Write {shared}/DESIGN_REVIEW.md with P0/P1 and actionable recommendations "
              "and a clear decision (approved / changes required). "
              "Do not implement apps or change UX_DESIGN.md. Commit review.")
        stage(slug, "design-revise", "claude", design,
              f"You are Claude, design owner. Read {shared}/DESIGN_REVIEW.md (independent "
              f"critique by Codex) and {shared}/UX_DESIGN.md. Update UX_DESIGN.md to address "
              "P0 issues, resolve missing states and platform inconsistencies, and clearly "
              "document any disagreements with the reviewer as explicit design decisions. "
              "Do not implement native app code. Commit revised design.")
        for platform in ("ios", "android"):
            # Import shared design into both independent native implementation branches.
            git("merge", "--no-edit", f"concept/{slug}/design", cwd=root / platform)
        # Both platforms are independently implemented by the SAME designated coder.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(stage, slug, f"build-{plat}", "codex", root / plat,
                            platform_prompt(slug, plat)): plat
                for plat in ("ios", "android")
            }
            errors = []
            for future in concurrent.futures.as_completed(futures):
                plat = futures[future]
                try:
                    future.result()
                    print(f"[{slug}] Codex {plat}: build step finished", flush=True)
                except Exception as e:
                    errors.append(f"{plat}: {e}")
            if errors:
                raise RuntimeError("; ".join(errors))
        # Claude reviews BOTH codebases, independently, without editing implementation.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(stage, slug, f"review-{plat}", "claude", root / plat,
                            code_review_prompt(slug, plat), readonly=True,
                            report=root / plat / shared / plat / "CLAUDE_REVIEW.md"): plat
                for plat in ("ios", "android")
            }
            errors = []
            for future in concurrent.futures.as_completed(futures):
                plat = futures[future]
                try:
                    future.result()
                except Exception as e:
                    errors.append(f"{plat}: {e}")
            if errors:
                raise RuntimeError("; ".join(errors))
        # Close the loop: coder addresses the review on each native codebase.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(stage, slug, f"fix-{plat}", "codex", root / plat,
                            f"Read {shared}/{plat}/CLAUDE_REVIEW.md (Claude's independent code review), "
                            f"and {shared}/UX_DESIGN.md (Claude design). Resolve P0/P1 issues "
                            "within your platform only; critically check UX against the design, "
                            "rebuild and run relevant tests, document remaining gaps, commit fixes. "
                            "Do not alter the other platform, publish or merge."): plat
                for plat in ("ios", "android")
            }
            errors = []
            for future in concurrent.futures.as_completed(futures):
                plat = futures[future]
                try: future.result()
                except Exception as e: errors.append(f"{plat}: {e}")
            if errors:
                raise RuntimeError("; ".join(errors))
        for plat in ("ios", "android"):
            (STATE / "logs" / slug / f"{plat}.exit").write_text("0")
        update(slug, phase="complete", completed_at=dt.datetime.now(dt.timezone.utc).isoformat())
        (STATE / "logs" / slug / "pipeline.exit").write_text("0")
        print(f"[{slug}] COMPLETE. Review and publish draft PRs manually.", flush=True)
        return 0
    except Exception as error:
        update(slug, phase="failed", error=str(error)[-1200:])
        (STATE / "logs" / slug / "pipeline.exit").write_text("1")
        print(f"[{slug}] FAILED safely: {error}", flush=True)
        return 1

def print_status(slug, data):
    phases = STATE / "logs" / slug
    print(f"{slug} [collaborative] phase={data.get('phase')}")
    for name, description in PHASES:
        marker = phases / f"{name}.exit"
        state = ("OK" if marker.read_text().strip() == "0" else "FAILED") if marker.exists() else "pending"
        print(f"  {state:7} {description}")
    if data.get("error"):
        print(f"  error: {data['error']}")

def show_workflow():
    for ix, (_, label) in enumerate(PHASES, 1):
        print(f"{ix}. {label}")
    print("No auto-merge. Draft PRs created only by explicit user command.")

if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "run":
        sys.exit(run_pipeline(sys.argv[2]))
    show_workflow()
