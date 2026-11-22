# Telegram Concept Lab

Public, code-first Telegram UX experiments for **iOS and Android**, developed in parallel by Codex and Claude Code.

## Native Mac app (recommended)

Open **Telegram Concept Lab.app** on the Mac Desktop (installed at \`~/Applications/Telegram Concept Lab.app\`).

This is a native SwiftUI interface with a text editor, explicit public-GitHub confirmation, live job/phase status, per-stage logs, Xcode/Android Studio launch links and manual draft PR controls. No Terminal or AppleScript menu is required. The old \`.command\` shortcut now forwards to this app.

To rebuild the app after pulling source updates, run \`./scripts/build-mac-app.sh\`. See [mac-app/README.md](mac-app/README.md).

Paperclip remains the task board; its default agent adapter is paused for safety. The native app executes the sandboxed local \`lab.py\` pipeline directly.

## One prompt, two implementations

On your Mac, run:

```bash
cd ~/Projects/telegram-concept-lab
python3 lab.py new animated-swipe-demo "Swipe a chat row to reveal configurable reply, archive and pin actions with spring physics."
python3 lab.py status
```

This starts a role-based pipeline (NOT one model per platform): **Claude designs both → Codex reviews design → Claude resolves feedback → Codex implements iOS and Android in parallel independent worktrees → Claude independently code-reviews both → Codex fixes both**. The work runs on the Mac, where simulators are installed. Legacy one-model-per-platform runs are retained read-only in existing worktrees; new concepts use the collaborative workflow.

```bash
python3 lab.py status
python3 lab.py workflow
python3 lab.py logs animated-swipe-demo pipeline
python3 lab.py logs multi-action-swipe ios
python3 lab.py logs multi-action-swipe android
python3 lab.py prs animated-swipe-demo
```

`prs` creates **draft GitHub PRs** for the completed, committed branches; review before merging. Worktree outputs and logs stay local and ignored. The CLI is a thin launcher, **not another persistent AI orchestrator**. Integrate with existing Paperclip via a command runner once its authenticated adapter is verified.

## Principles

- Code and runnable demos, not exported animation videos.
- Two native codebases, one shared behavior contract and acceptance criteria.
- The repository is PUBLIC, including original concept prompts inside SPEC.md and both native implementations. Execution logs and local run state stay private on the Mac.
- No auto-merge, no unattended paid tool installation or publishing. Review stages are real model invocations, not a written claim of verification.
- Do not claim actual Telegram integration unless tested in official Telegram codebase.
- Review each platform and parity before publishing a demo.

## Requirements

macOS with Xcode, Android Studio + SDK, Git, GitHub CLI authenticated, Codex CLI authenticated, Claude Code authenticated, Homebrew openjdk@17 for Gradle (pinned for Android runs only). Run `python3 lab.py doctor` for checks. See `AGENTS.md` and `DESIGN.md`.

## Agent safety and verified prerequisites

- Claude runs with native Bash sandbox, fail-if-unavailable enabled, no inherited MCP connectors, and blocks reads/writes outside working directories. Both code reviews use read-only planning mode.
- Codex uses a private isolated CODEX_HOME with existing ChatGPT OAuth credentials and no global MCP servers or plugins. Approve-for-me applies workspace-write sandboxing.
- System-wide JDK 25 is incompatible with Gradle 8.14. Android builds use Homebrew JDK 17, scoped to Android jobs.
- Orchestrator commits only model-assigned content, then creates draft PRs only on explicit request.
- Paperclip agents remain paused due unsafe default adapter invocation. Use the Desktop launcher for live runs.
