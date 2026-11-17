# Shared contract for Codex and Claude Code

This repository is PUBLIC. Never commit secrets, private files, personal data, simulator caches, credentials, or agent logs. Stay inside assigned worktree.
Purpose: high-quality, executable Telegram interaction concepts for iOS and Android.
Each concept must be independently runnable, with README, reproducible build instructions, known limitations and demo guidance.
One shared behavior specification lives at concepts/<slug>/SPEC.md (created in main before launching).
Codex and Claude work on independent branches/worktrees, never the same files.
iOS: Swift, UIKit, CoreAnimation, Metal only if justified, with Xcode project and simulator build.
Android: Kotlin and Android SDK (Views or Compose, choose to suit actual Telegram integration); with Gradle project and emulator build.
No invented backend features. Stub data must be openly labeled. Don't copy Telegram trademarks/assets when licensing is uncertain.
Support cancel/interrupt interactions, haptics where sensible, accessibility and reduced motion.
Report exact verification commands and results; never claim unexecuted builds passed.
Do not install paid tooling, push to stores, merge PRs, or change other repositories.

Official Telegram source trees for read-only reference: ~/Projects/telegram-upstreams/Telegram-iOS and ~/Projects/telegram-upstreams/Telegram-Android. Do not edit them directly or copy their entire contents into this public repository. Integrate via isolated upstream forks/worktrees and documented patches; follow Telegram license and developer branding rules.
