#!/usr/bin/env bash
CITY="Toronto"
CACHE="/tmp/tmux-weather-$USER"
TTL=900 # refresh every 15 min

age() { echo $(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0))); }

if [ ! -s "$CACHE" ] || [ "$(age)" -gt "$TTL" ]; then
  out=$(curl -fsm 3 "wttr.in/${CITY// /+}?format=%C+%t" 2>/dev/null)
  [[ "$out" =~ [0-9]°[CF]$ ]] && echo "$out" >"$CACHE"
fi

case "$1" in
city) echo "$CITY" ;;
*) cat "$CACHE" 2>/dev/null | tr -d '\n' ;;
esac
