# Official Telegram upstreams — local, auto-updated source mirrors

Source URLs:
- iOS https://github.com/TelegramMessenger/Telegram-iOS (master)
- Android https://github.com/DrKLO/Telegram (master)

Local clean clones (outside this public repo):
- `~/Projects/telegram-upstreams/Telegram-iOS`
- `~/Projects/telegram-upstreams/Telegram-Android`

Auto-update uses launchd agent `id.vsdsgn.telegram-upstreams`, daily at 09:00 local Mac time (and once on loading the job). It runs `scripts/update_upstreams.sh`, fetches upstream and uses `git merge --ff-only` only on a pristine original branch. If any local changes or diverging commit history exist, the merge is skipped; no reset, stash or force operation.

Logs: `~/Library/Logs/TelegramConceptLab/upstream-updates.log`.

**Important:** The source clones are shallow, using blob filters, and are not yet fully prepared for compiling Telegram. Upstream submodules, Bazel dependencies (iOS), Android NDK and application-specific credentials are separate setup steps. Neither clone is a fork or a modified Telegram app. Our experiments remain under `concepts/` and draft PRs until a tested integration patch is made.

Telegram's open-source licenses and developer guidance apply. Never reuse their app branding for a separately distributed client or commit API credentials to this public repository.
