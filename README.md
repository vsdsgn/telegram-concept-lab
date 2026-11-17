# Telegram Concept Lab

Public, code-first Telegram UX experiments for **iOS and Android**, developed in parallel by Codex and Claude Code.

## One prompt, two implementations

On your Mac, run:

```bash
cd ~/Projects/telegram-concept-lab
python3 lab.py new multi-action-swipe "Swipe a chat row to reveal configurable reply, archive and pin actions with spring physics."
python3 lab.py status
```

This starts **Codex on iOS (Swift/UIKit)** and **Claude on Android (Kotlin/Views)** simultaneously, each in an isolated Git worktree and feature branch. You can reverse assignments with `--swap`, or create a new iteration with a new concept slug. The command prints job IDs and log locations. Each agent builds/tests on the local Mac where simulators are installed.

```bash
python3 lab.py status
python3 lab.py logs multi-action-swipe ios
python3 lab.py logs multi-action-swipe android
python3 lab.py prs multi-action-swipe
```

`prs` creates **draft GitHub PRs** for the completed, committed branches; review before merging. Worktree outputs and logs stay local and ignored. The CLI is a thin launcher, **not another persistent AI orchestrator**. Integrate with existing Paperclip via a command runner once its authenticated adapter is verified.

## Principles

- Code and runnable demos, not exported animation videos.
- Two native codebases, one shared behavior contract and acceptance criteria.
- Only the repository is public; prompts, runs and logs are local.
- No auto-merge, no unattended paid tool installation or publishing.
- Do not claim actual Telegram integration unless tested in official Telegram codebase.
- Review each platform and parity before publishing a demo.

## Requirements

macOS with Xcode, Android Studio + SDK, Git, GitHub CLI authenticated, Codex CLI authenticated, Claude Code authenticated. Run `python3 lab.py doctor` for checks. See `AGENTS.md` and `DESIGN.md`.
