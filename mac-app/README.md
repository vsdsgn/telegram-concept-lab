# Native macOS launcher

Installed app: `~/Applications/Telegram Concept Lab.app`

Desktop shortcut: `~/Desktop/Telegram Concept Lab.app`

This is a **real SwiftUI macOS app** (not AppleScript, Electron, web dashboard or a Terminal menu). It is a local UI for the existing `lab.py` and `collab.py` orchestrators.

## Usage

1. Open the desktop **Telegram Concept Lab.app** icon.
2. Click **Новый концепт**, enter your prompt and explicitly confirm that the spec/code will be published to a **public** GitHub repository.
3. Click **Запустить Claude + Codex**. The app calls `python3 lab.py new <slug> <prompt>` and returns after the background pipeline starts.
4. View the concept in the left sidebar; status and 11 stages (including native build checks) refresh every 3 seconds. Select a stage to read its model log.
5. If a stage fails, click **Продолжить с места ошибки**. Already verified work is not repeated. **Остановить** cancels the worker group while preserving completed stages.
6. After both models finish, independently verify the iOS Xcode simulator build and Android Gradle build/unit tests. The **Проверить сборки** button lets you repeat this check.
7. Once both verifications pass, review the Xcode and Android Studio apps, then use **Создать черновые PR**. No auto-merge.

The Python pipeline runs locally on the Mac **independently of the app window**. Keep the Mac on and awake while it runs; closing the app does not cancel an already running job.

## Build / install

```sh
cd ~/Projects/telegram-concept-lab
./scripts/build-mac-app.sh
```

Requirements: macOS 14+ with Xcode command line tools; existing Python toolchain and model CLI authorizations are verified with `python3 lab.py doctor`. Installation uses ad-hoc signing, so it is intended for this Mac rather than distributing to others.

The legacy command script forwards to the native app, while its old Desktop shortcut is removed during installation. Use the new native app shortcut so Terminal never opens.

**Paperclip** is a separate project/task dashboard; its bundled remote model adapters are intentionally paused because they tried to disable the CLI sandbox. The native Mac app does not rely on those adapters or grant new remote privileges.

## Status and limitations

- Native app compilation/signing and Finder launch verified.
- Backend tools and native sample projects were checked separately.
- The full 9-stage production flow with a newly generated concept is **not yet end-to-end verified**; the first real run may reveal further issues.
- The GUI currently starts new concepts, tracks job status/logs and opens projects/draft PRs. Revision cycles, native previews embedded in the app, and secure remote Paperclip-triggered execution are not yet implemented.

## Troubleshooting

- An existing concept which failed before the recovery fix can be resumed with **Продолжить с места ошибки**.
- New and resumed local jobs prevent idle sleep through macOS caffeinate.
- Failed builds block PR creation. Evidence is in .lab/logs/<slug>/verify-ios.log and verify-android.log.
- The native app starts local sandboxed agents. Paperclip's remote agent adapters stay paused for security.
