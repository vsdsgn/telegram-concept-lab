# Native macOS launcher

Installed app: `~/Applications/Telegram Concept Lab.app`

Desktop shortcut: `~/Desktop/Telegram Concept Lab.app`

This is a **real SwiftUI macOS app** (not AppleScript, Electron, web dashboard or a Terminal menu). It is a local UI for the existing `lab.py` and `collab.py` orchestrators.

## Usage

1. Open the desktop **Telegram Concept Lab.app** icon.
2. Click **Новый концепт**, enter your prompt and explicitly confirm that the spec/code will be published to a **public** GitHub repository.
3. Click **Запустить Claude + Codex**. The app calls `python3 lab.py new <slug> <prompt>` and returns after the background pipeline starts.
4. View the concept in the left sidebar; status and 9 stages refresh every 3 seconds. Select a stage to read its model log.
5. When all stages pass, review the native Xcode and Android Studio apps; use **Создать черновые PR** to publish platform branches to GitHub. There is no auto-merge.

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
