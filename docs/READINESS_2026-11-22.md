# Telegram Concept Lab — readiness report (2026-11-22)

## What is ready

- macOS launcher: Desktop > **Telegram Concept Lab.command**.
- Role-based collaboration: Claude designs UX for both platforms; Codex independently critiques that design; Claude revises; Codex implements iOS and Android in isolated parallel worktrees; Claude reviews both codebases read-only; Codex fixes findings. Human reviews draft PRs before merging.
- macOS developer tools: Xcode, iOS Simulator, Android Studio, Android SDK/emulator, Git, GitHub CLI, Codex CLI and Claude Code authenticated.
- Existing Multi-Action Swipe pilot: native iOS and Android projects built independently as a verification baseline.
- Paperclip on VPS can connect to the Mac over private loopback SSH tunnel; remote environment probe passed. Its native Codex/Claude agents are deliberately **paused** because the bundled remote CLI adapter attempted sandbox bypass. Use the Mac launcher, not Paperclip, for executable jobs.

## Actual checks

| Check | Result |
|---|---|
| iOS xcodebuild, Multi-Action Swipe | exit 0 |
| Android Gradle assembleDebug + testDebugUnitTest with Homebrew JDK 17 | exit 0 |
| Claude OAuth, sandboxed read-only smoke | exit 0 |
| Claude sandboxed UX design file creation (local throwaway) | exit 0 |
| Codex isolated OAuth read-only smoke | exit 0 |
| Codex independent UX critique file creation (local throwaway) | exit 0 |
| Python orchestrator tests (role handoff, sandbox flags, scoped commits, forbidden change rejection) | 3 passing |
| Script syntax and CLI environment doctor | successful |

The two genuine AI test artifacts are stored privately at `.lab/checks/smoke-UX_DESIGN.md` and `.lab/checks/smoke-DESIGN_REVIEW.md` on the Mac; they are not public GitHub artifacts.

## Security and reproducibility

- Claude CLI uses sandbox.enabled=true and failIfUnavailable=true, limited file tools, no inherited MCP connectors, and blocks reads/writes outside working directories. Claude code-review stages run in read-only plan mode.
- Codex CLI uses its own private CODEX_HOME with a minimal config and linked existing ChatGPT authentication. The `--approve-for-me` flag enforces a workspace-write sandbox. No unrestricted adapter is launched.
- Model agents edit only assigned paths. Local Python orchestrator validates artifacts and creates Git commits. Public PRs are not created automatically.
- Gradle 8.14 projects use `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` for Android work; global JDK 25 remains untouched.
- GitHub repository is **public**: ideas in SPEC.md and code may become public. Do not include confidential assets, credentials, personal or company information.
- Daily Telegram source updater continues to fetch/reconcile official iOS and Android source trees separately.

## Usage

1. Double-click **Telegram Concept Lab.command** on Mac Desktop.
2. Select **Новый концепт**, describe interaction and confirm public-GitHub submission.
3. Open the launcher again to inspect **Статус запусков** or **Открыть логи**.
4. Test native outputs on the simulator/emulator.
5. When all phases succeed, select **Создать черновые PR**, review and only then merge.

## Still not proven / not enabled

- The **complete nine-phase workflow has not yet been executed with real models from start to finish** on a newly generated concept. Individual model writes, independent critiques, simulated complete orchestration and native builds were tested separately.
- No physical device haptics, real-device accessibility testing or instrumented 60 fps guarantee.
- Paperclip-managed agent invocation remains paused until its CLI sandbox-bypass behavior can be safely replaced or executed in a genuinely isolated OS account/container.
- Node.js runtime on the Paperclip VPS reports v22 while the installed Paperclip CLI expects v24.11+. Production server was not upgraded.

Current canonical code: https://github.com/vsdsgn/telegram-concept-lab
