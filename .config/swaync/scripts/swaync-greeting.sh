#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/swaync/config.json"
TMP="$(mktemp)"

NAME="jkebwdn"

# ----- Greeting line (by time of day) -----
H=$(date +%H)
if   (( H < 5  )); then PART="Night"
elif (( H < 12 )); then PART="Morning"
elif (( H < 17 )); then PART="Afternoon"
else                  PART="Evening"
fi
GREETING="Good ${PART}, ${NAME}"

# ----- Date line -----
DATE_LINE="$(date "+%A %d %B")"

# ----- Weather (optional; tiny and resilient). Edit CITY if you want. -----
CITY="Leicester"
WEATHER_DESC="$(
  curl -m 2 -fsSL "https://wttr.in/${CITY}?format=%C" 2>/dev/null || echo "Partly cloudy"
)"
WEATHER_LINE="Weather: ${WEATHER_DESC}"

NEW_TEXT="${GREETING}
${DATE_LINE}
${WEATHER_LINE}"

# Write JSON atomically
jq --arg t "$NEW_TEXT" '
  .["widget-config"]["title#Greeting"].text = $t
| .["widget-config"]["title#Greeting"]["use-markup"] = false
' "$CONFIG" >"$TMP" && mv "$TMP" "$CONFIG"

# Reload SwayNC (config + css)
swaync-client -R
swaync-client -rs


