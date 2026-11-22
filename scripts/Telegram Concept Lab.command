#!/bin/zsh
# Compatibility shortcut: the old .command icon now opens the native macOS app.
# Use "Telegram Concept Lab.app" on the Desktop to avoid Terminal entirely.
APP="$HOME/Applications/Telegram Concept Lab.app"
if [[ -d "$APP" ]]; then
  /usr/bin/open -a "$APP"
  exit $?
fi
echo "Telegram Concept Lab.app has not been built yet."
echo "Run this once to install it:"
echo "  $HOME/Projects/telegram-concept-lab/scripts/build-mac-app.sh"
exit 1
