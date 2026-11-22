#!/bin/zsh
# Safely fast-forward pristine official Telegram source trees.
# Never reset, stash, force-push, or touch the Concept Lab worktrees.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$HOME/Projects/telegram-upstreams"
LOGDIR="$HOME/Library/Logs/TelegramConceptLab"
mkdir -p "$LOGDIR"
exec >> "$LOGDIR/upstream-updates.log" 2>&1
print "========== $(date -u '+%Y-%m-%dT%H:%M:%SZ') =========="
for name in Telegram-iOS Telegram-Android; do
  dir="$ROOT/$name"
  if [[ ! -d "$dir/.git" ]]; then
    print "$name: missing/incomplete clone; skip"
    continue
  fi
  current="$(git -C "$dir" branch --show-current 2>/dev/null)"
  target="$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  if [[ -z "$current" || -z "$target" ]]; then
    print "$name: can't identify branch; skip"
    continue
  fi
  expected="${target#origin/}"
  if [[ "$current" != "$expected" ]]; then
    print "$name: branch $current != $expected; fetch only"
  fi
  old="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
  if ! git -C "$dir" fetch --prune origin "$expected"; then
    print "$name: FETCH ERROR (existing checkout unchanged)"
    continue
  fi
  # A submodule's separately checked-out HEAD is not a tracked source edit.
  # Respect all regular tracked/untracked changes while never checking out,
  # resetting or overwriting any nested repository contents.
  if [[ -n "$(git -C "$dir" status --porcelain --ignore-submodules=all 2>/dev/null)" || "$current" != "$expected" ]]; then
    print "$name: tracked/untracked source changes or unexpected branch; fetched only"
    continue
  fi
  # If upstream changed any gitlink (mode 160000), a fast-forward could leave
  # user's nested checkouts inconsistent. Require a manual submodule review.
  gitlinks="$(git -C "$dir" diff --raw HEAD "origin/$expected" 2>/dev/null | grep -E '^:160000 |^:[0-9]{6} 160000 ' || true)"
  if [[ -n "$gitlinks" ]]; then
    print "$name: upstream changes submodule revisions; fetched only, review before merge"
    continue
  fi
  if git -C "$dir" merge --ff-only "origin/$expected"; then
    print "$name: updated $old -> $(git -C "$dir" rev-parse --short HEAD)"
  else
    print "$name: ff-only refused; left unchanged for review"
  fi
  if [[ -f "$dir/.gitmodules" ]]; then
    print "$name: NOTE nested dependencies/submodules are not auto-updated; run build preparation explicitly"
  fi
done
print "========== finished =========="
