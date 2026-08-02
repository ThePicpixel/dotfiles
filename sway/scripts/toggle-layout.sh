#!/bin/sh
set -e

STATE_FILE="$HOME/.config/sway/kb-layout.conf"
mkdir -p "$(dirname "$STATE_FILE")"

current="fr"
if [ -f "$STATE_FILE" ]; then
    case "$(cat "$STATE_FILE")" in
        *xkb_layout\ us*) current="us" ;;
        *xkb_layout\ fr*) current="fr" ;;
        *) current="fr" ;;
    esac
fi

if [ "$current" = "fr" ]; then
    new="us"
else
    new="fr"
fi

swaymsg "input type:keyboard xkb_layout $new" >/dev/null
echo "input type:keyboard xkb_layout $new" > "$STATE_FILE"
