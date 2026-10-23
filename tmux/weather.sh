#!/usr/bin/env bash
CITY="Toronto"
CACHE="/tmp/tmux-weather-$USER"
TTL=900 # refresh every 15 min

age() { echo $(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0))); }

# For MacOS
if [ "$(uname)" = "Darwin" ]; then
  if [ ! -s "$CACHE" ] || [ "$(age)" -gt "$TTL" ]; then
    out=$(curl -fsm 3 "wttr.in/${CITY// /+}?format=%c%t" 2>/dev/null)
    [ -n "$out" ] && echo "$out" >"$CACHE"
  fi
  case "$1" in
  city) echo "$CITY" ;;
  *) cat "$CACHE" 2>/dev/null | tr -d '\n' ;;
  esac
  exit 0
fi

# For WSL and Linux
if [ ! -s "$CACHE" ] || [ "$(age)" -gt "$TTL" ]; then
  raw=$(curl -fsm 3 "wttr.in/${CITY// /+}?format=%C|%t" 2>/dev/null)
  [[ "$raw" =~ ^[^|]+\|[+-]?[0-9]+ ]] && echo "$raw" >"$CACHE"
fi

icon_for() {
  local c hour
  c=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  hour=$(date +%H)
  case "$c" in
  *thunder*) printf '\ue31d' ;;
  *snow* | *blizzard* | *ice*) printf '\ue31a' ;;
  *sleet*) printf '\ue3aa' ;;
  *rain* | *drizzle* | *shower*) printf '\ue318' ;;
  *fog* | *mist* | *haze*) printf '\ue313' ;;
  *partly*) printf '\ue302' ;;
  *overcast* | *cloud*) printf '\ue312' ;;
  *sunny* | *clear*)
    if [ "$hour" -ge 20 ] || [ "$hour" -lt 6 ]; then printf '\ue32b'; else printf '\ue30d'; fi
    ;;
  *) printf '\ue33d' ;;
  esac
}

case "$1" in
city) echo "$CITY" ;;
*)
  [ -s "$CACHE" ] || exit 0
  cond=$(cut -d'|' -f1 "$CACHE")
  temp=$(cut -d'|' -f2 "$CACHE" | tr -d '\n')
  printf '%s %s' "$(icon_for "$cond")" "$temp"
  ;;
esac
