
> **Official Telegram client builds (2026-11-22):** Both **genuine original Telegram apps have been built and installed** from isolated feature branches, not mock demos. iOS 13.2 complete Bazel `//Telegram:Telegram` build passed, archive `~/Projects/telegram-integrations/Telegram-iOS-reaction-wheel/bazel-bin/Telegram/Telegram.ipa` (~616 MiB) verified and successfully installed/launched as `ph.telegra.Telegraph` on iPhone 17 / iOS 26.1 simulator. Android Beta 13.2.2 real `assembleAfatDebug` APK (75,197,332 bytes) built, signature verified, installed and launched on `ds_android` Android 16 emulator. The radial reaction source compiles in both apps; Android debug `reaction_wheel_dev=true` verified and its **Test Backend** enabled on the emulator login screen. **Runtime gesture acceptance in a logged-in real message remains unverified** on both clients. Mac native UI opens both official clients and their build artifacts. iOS logs `ios-full-app-wheel-fix3.log`, Android `android-final-wheel-apk-build.log`; status markers both exit `0`. Original upstream master trees untouched, private credentials not copied. Note: the local Xcode distribution lacks graphical `Simulator.app` though `simctl` / iOS 26.1 runtime work; iOS on-device launch was verified via `simctl`, screenshot captured; GUI button launches the installed app via `simctl` and opens the captured screenshot, not a non-existent interactive Simulator UI.

> **IMPORTANT:** Historical Concept Lab jobs are standalone mock demos, NOT modifications of Telegram. The official clients are checked out separately under `~/Projects/telegram-integrations/Telegram-iOS-reaction-wheel` and `Telegram-Android-reaction-wheel`. `lab.py new` requires `--demo` to avoid silently creating more mocks.

# Telegram Concept Lab

## Telegram TEST DC (both official clients)

Both genuine official Telegram clients are configured for **Telegram Test DC**, not mock screens. Production Telegram apps and accounts remain separate.

- **Android:** the `org.telegram.messenger.beta` debug variant forces Test DC on new unauthenticated sessions and locks the `Test Backend` checkbox. A dedicated fresh AVD `telegram_concept_test_dc` has 10 GB of storage, and the real APK is installed. In `Telegram Concept Lab.app`, open `Telegram · Test DC` → `Открыть Telegram · Test DC` to view it.
- **iOS:** the isolated simulator debug app sets `testingEnvironment=true` and uses the separate persistent app-group directory `telegram-concept-lab-test-data`. The existing `--ui-test` path instead uses temporary `telegram-ui-tests-data` and intentionally wipes only that UI test directory per run. iOS build log: `~/Projects/telegram-integrations/ios-test-dc-full-bazel-build-v2.log`. The dedicated iPhone 17 simulator `Telegram Concept Lab Test DC` is accessible with `simctl`; the GUI `Simulator.app` is absent from this Mac's Xcode distribution.
- **Login:** Test DC supports disposable `+99966XYYYY` numbers, X=1/2/3; the login code is five repetitions of X. Example: `+9996621234` → `22222`. Use different test numbers for two test participants. Never enter real account data, contacts, private conversations or passwords on Test DC.
- **Acceptance:** Builds, installation and separate persistent test mode do not by themselves validate Reaction Wheel gesture behavior. Verify reaction drag/commit/cancel and normal fallback with real messages between two authenticated TEST accounts.


Public, code-first Telegram UX experiments for **iOS and Android**, developed in parallel by Codex and Claude Code.

## Native Mac app (recommended)

Open **Telegram Concept Lab.app** on the Mac Desktop (installed at `~/Applications/Telegram Concept Lab.app`).

This is a native SwiftUI interface with a text editor, explicit public-GitHub confirmation, live job/phase status, per-stage logs, Xcode/Android Studio launch links and manual draft PR controls. No Terminal or AppleScript menu is required. The legacy command script forwards to this app, but its old Desktop shortcut has been removed so only the native app icon remains.

To rebuild the app after pulling source updates, run `./scripts/build-mac-app.sh`. See [mac-app/README.md](mac-app/README.md).

Paperclip remains the task board; its default agent adapter is paused for safety. The native app executes the sandboxed local `lab.py` pipeline directly.

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

## One-click preview

After builds pass, click **Демо iOS** or **Демо Android** in the native Mac app. It installs and launches the compiled prototype directly on an available simulator/emulator, takes screenshots, and shows them inside the Concept Lab window. Xcode/Android Studio are optional for code inspection.

## Reliable execution and recovery

The native Mac app now offers Stop, Resume, and Verify builds. Completed Claude/Codex stages are retained across failures; output written by a successfully finished model can be recovered without paying for the same generation again. New and resumed jobs prevent idle sleep.

Full project completion requires independent Xcode simulator compilation and offline Gradle build/tests (verify.py); only then does the app enable draft PR creation.

## Agent safety and verified prerequisites

- Claude runs with native Bash sandbox, fail-if-unavailable enabled, no inherited MCP connectors, and blocks reads/writes outside working directories. Both code reviews use read-only planning mode.
- Codex uses a private isolated CODEX_HOME with existing ChatGPT OAuth credentials and no global MCP servers or plugins. Approve-for-me applies workspace-write sandboxing.
- System-wide JDK 25 is incompatible with Gradle 8.14. Android builds use Homebrew JDK 17, scoped to Android jobs.
- Orchestrator commits only model-assigned content, then creates draft PRs only on explicit request.
- Paperclip agents remain paused due unsafe default adapter invocation. Use the Desktop launcher for live runs.

## Native source workflow (real Telegram, not mocks)

The SwiftUI launcher now has a dedicated native Telegram iOS + Android creation action.

- CLI: python3 native.py doctor | python3 native.py new my-native-idea "interaction request" | python3 native.py status.
- Native concepts fork local concept-lab/reaction-wheel feature branches into isolated Git worktrees. Original branches stay intact. Existing Reaction Wheel patches are part of the base.
- UX specs and logs remain private under ignored .lab/native/<slug>; no upstream pushes, merges or publications.
- Claude designs/reviews both clients, Codex critiques UX and writes/fixes both genuine native codebases. No standalone mocks in this path.
- Protected auth, signing and Test DC source edits halt the workflow. This path-based safeguard is not a formal security audit.
- Phase ready-for-build-review is NOT a passing Bazel/Gradle build, and NOT in-chat gesture E2E. Test accounts, real messages and actual animations need subsequent verification.
- Native jobs and log folders appear in the macOS application. Legacy standalone jobs remain separate.

The brand-new full live native Claude + Codex run has not yet been end-to-end validated. Do not use production Telegram credentials.
