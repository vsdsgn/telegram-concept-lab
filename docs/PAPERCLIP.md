# Paperclip ↔ Telegram Concept Lab — secure implementation plan

## Verified 2026-11-17
- Existing Paperclip service on VPS is healthy on 127.0.0.1:3106.
- Unauthenticated company API returns HTTP 403; current CLI 'whoami' returns 401. No board-authorized session is available to this command execution context. Never modify Paperclip database directly.
- Paperclip CLI warns host Node v22.23.2 is unsupported; requires Node 24.11+ (service remains running). Upgrade separately with backup and rollback, not as an incidental change.
- Mac can build iOS and Android and run Codex + Claude. macOS SSH on port 22 is closed; no Tailscale is installed.
- Current working command flow: lab.py -> isolated Codex iOS / Claude Android worktrees -> draft GitHub PRs. Both original prototypes built successfully.

## Recommended architecture
One existing VPS Paperclip (no duplicate dashboard), a distinct personal Studio company/project within it, two agents bound to Mac execution only. Use an SSH execution environment over an authenticated private tunnel (e.g. Tailscale or WireGuard), with a dedicated restricted user and SSH key, not open public SSH. Paperclip issues define task context and approval state; local builders produce git branches, build evidence, logs and draft PR links.

## Required steps once authenticated
1. Sign in as a Paperclip Board operator via the normal UI / official CLI 'connect'. Do not paste a board token or password into GitHub or this public repository.
2. Confirm installed Paperclip supports experimental Environments (Settings -> Experimental -> Enable Environments). Docs: https://github.com/paperclipai/paperclip-docs/blob/main/docs/experimental/environments.md
3. Independently secure a private network path VPS -> Mac and test key-only SSH. Do not enable public internet login to the Mac.
4. Settings -> Environments -> Add SSH environment. Specify restricted user, remote folder and private host, then Test.
5. Create personal Concept Lab project with Codex and Claude runtime adapters, separate working directories and no full-auto access outside repository. Assign one job per platform/branch.
6. Test with non-destructive read-only issue before allowing builds. Connect PRs and statuses; add explicit stop and budgets.
7. Human sign-off before merge, app publishing, spending, deployment or credentials changes.

## Blocked — not done
- No Paperclip personal project/agents were created or modified.
- No Mac SSH or private tunnel was opened.
- No Node, API auth or production Paperclip settings were changed.
- No continuous Paperclip-to-Mac orchestration yet. The local Codex/Claude CLI flow is functional in the meantime.
