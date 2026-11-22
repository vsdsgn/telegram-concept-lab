#!/bin/zsh
# Double-click launcher for one-prompt iOS + Android concept workflow.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$HOME/Projects/telegram-concept-lab"
cd "$ROOT" || { echo "Project directory not found: $ROOT"; read -k 1; exit 1; }

function message_dialog() {
  /usr/bin/osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"OK"} default button "OK" with title "Telegram Concept Lab"' -e 'end run' -- "$1" >/dev/null 2>&1 || true
}
function show_status() {
  echo ""
  echo "=== Telegram Concept Lab ==="
  python3 "$ROOT/lab.py" status
  echo ""
  echo "Repository: https://github.com/vsdsgn/telegram-concept-lab"
  echo "Paperclip: https://asya.188-245-144-65.sslip.io/"
}
if [[ "${1:-}" == "--status" ]]; then show_status; exit 0; fi
if [[ "${1:-}" == "--doctor" ]]; then python3 "$ROOT/lab.py" doctor; exit 0; fi

CHOICE=$(/usr/bin/osascript <<'APPLESCRIPT'
set actions to {"Новый концепт — Codex iOS + Claude Android", "Статус запусков", "Создать черновые PR из готовых сборок", "Открыть готовый iOS-прототип", "Открыть готовый Android-прототип", "GitHub: задачи и PR", "Paperclip: управление"}
set selection to choose from list actions with title "Telegram Concept Lab" with prompt "Что делаем?" default items {item 1 of actions} without multiple selections allowed
if selection is false then
    return "cancel"
end if
return item 1 of selection
APPLESCRIPT
)
[[ "$CHOICE" == "cancel" || -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
  "Новый концепт"*)
    PROMPT=$(/usr/bin/osascript <<'APPLESCRIPT'
try
    set answerText to text returned of (display dialog "Опиши поведение, анимацию и сценарий. Одна задача — две нативные реализации." with title "Новый Telegram-концепт" default answer "" buttons {"Отмена", "Продолжить"} default button "Продолжить")
    return answerText
on error number -128
    return ""
end try
APPLESCRIPT
)
    if [[ -z "${PROMPT//[[:space:]]/}" ]]; then
      message_dialog "Описание пустое. Ничего не запускал."
      exit 0
    fi
    APPROVE=$(/usr/bin/osascript <<'APPLESCRIPT'
try
    set reply to display dialog "Текст идеи и код будут размещены в ПУБЛИЧНОМ GitHub-репозитории. Не включай приватную информацию, токены или корпоративные материалы. Запустить Codex и Claude одновременно?" with title "Подтвердить публикацию" buttons {"Отмена", "Запустить"} default button "Отмена" with icon caution
    return button returned of reply
on error number -128
    return "Отмена"
end try
APPLESCRIPT
)
    [[ "$APPROVE" != "Запустить" ]] && exit 0
    SLUG="concept-$(/bin/date '+%Y%m%d-%H%M%S')"
    echo "Starting: $SLUG"
    python3 "$ROOT/lab.py" new "$SLUG" "$PROMPT"
    STATUS=$?
    if [[ "$STATUS" -eq 0 ]]; then
      message_dialog "Создан $SLUG. Codex и Claude запущены. Для прогресса открой этот ярлык снова → Статус запусков."
      show_status
    else
      message_dialog "Запуск завершился с ошибкой. Открой Terminal и проверь вывод."
    fi
    ;;
  "Статус"*)
    show_status
    message_dialog "Статус и названия веток показаны в окне Terminal. Для результатов открой GitHub → Pull requests."
    ;;
  "Создать черновые PR"*)
    LAST_SLUG=$(python3 -c 'import json;from pathlib import Path;p=Path(".lab/jobs.json");d=json.loads(p.read_text()) if p.exists() else {};print(next(reversed(d),""))')
    if [[ -z "$LAST_SLUG" ]]; then
      message_dialog "Запусков пока нет. Сначала создай новый концепт."
      exit 0
    fi
    SLUG=$(/usr/bin/osascript -e 'on run argv' -e 'try' -e 'return text returned of (display dialog "Укажи slug готового концепта. Сначала проверь статус запусков." with title "Создать черновые GitHub PR" default answer (item 1 of argv) buttons {"Отмена", "Продолжить"} default button "Отмена")' -e 'on error number -128' -e 'return ""' -e 'end try' -e 'end run' -- "$LAST_SLUG")
    [[ -z "$SLUG" ]] && exit 0
    echo "Creating draft PRs for $SLUG"
    python3 "$ROOT/lab.py" prs "$SLUG"
    open "https://github.com/vsdsgn/telegram-concept-lab/pulls"
    ;;
  "Открыть готовый iOS"*)
    open "$ROOT/.lab/worktrees/multi-action-swipe/ios/concepts/multi-action-swipe/ios/MultiActionSwipe.xcodeproj"
    message_dialog "Открыл iOS-проект в Xcode. Выбери iPhone Simulator сверху и нажми ▶ Run. Новые концепты находятся в .lab/worktrees/<slug>/ios."
    ;;
  "Открыть готовый Android"*)
    ANDROID="$ROOT/.lab/worktrees/multi-action-swipe/android/concepts/multi-action-swipe/android"
    open -a "Android Studio" "$ANDROID"
    message_dialog "Открыл Android-проект. Выбери эмулятор сверху и нажми ▶ Run. Новые концепты находятся в .lab/worktrees/<slug>/android."
    ;;
  "GitHub"*)
    open "https://github.com/vsdsgn/telegram-concept-lab/pulls"
    ;;
  "Paperclip"*)
    open "https://asya.188-245-144-65.sslip.io/"
    message_dialog "Paperclip уже видит Mac, но запуск двух агентов в нём пока отключён по соображениям безопасности. Создавать задачи можно, запускать через этот ярлык."
    ;;
esac
echo ""
echo "Telegram Concept Lab · window can be closed"
