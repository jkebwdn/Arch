#!/usr/bin/env bash
# Bluetooth Wofi menu — resilient scan + pair + connect
# - Powers on, makes discoverable/pairable
# - Applies permissive scan policy (transport auto, duplicate on)
# - Lists paired + discovered devices
# - Pair/Trust/Connect flow
# jkebwdn — stable build

set -u
set -o pipefail

WOFI=(/usr/bin/wofi --conf /home/jkebwdn/.config/wofi/config)
BTCTL=/usr/bin/bluetoothctl

# One-shot wrapper: never block forever
bt() { timeout 3 "$BTCTL" -- "$@" 2>/dev/null || true; }

# Send multiple commands to bluetoothctl (non-interactive)
btc() { printf "%s\n" "$@" | "$BTCTL" 2>/dev/null || true; }

# Ensure controller is ready & permissive
prep_controller() {
  btc \
    "agent NoInputNoOutput" \
    "default-agent" \
    "power on" \
    "discoverable on" \
    "pairable on"
}

# Widen discovery filter like you did via `menu scan`
prep_scan_policy() {
  btc \
    "menu scan" \
    "transport auto" \
    "duplicate-data on" \
    "back"
}

is_scanning() {
  bt show | awk '/Discovering:/ {print $2}'
}

scan_on()  { bt scan on;  }
scan_off() { bt scan off; }

list_paired()     { bt paired-devices   | sed -n 's/^Device \([0-9A-F:]\+\) \(.*\)$/🪩  \1  \2/pI'; }
list_discovered() { bt devices          | sed -n 's/^Device \([0-9A-F:]\+\) \(.*\)$/📡  \1  \2/pI'; }

pair_trust_connect() {
  mac="$1"
  btc "pair $mac"
  btc "trust $mac"
  btc "connect $mac"
}

toggle_connect() {
  mac="$1"
  if bt info "$mac" | grep -q "Connected: yes"; then
    bt disconnect "$mac"
  else
    bt connect "$mac"
  fi
}

# --- main loop ---
prep_controller
prep_scan_policy

# If not already scanning, start a short scan to populate the list
[ "$(is_scanning)" = "yes" ] || scan_on

while :; do
  paired="$(list_paired)"
  discovered="$(list_discovered)"

  # Build header line showing scan state
  scan_state="$(is_scanning)"
  [ "$scan_state" = "yes" ] && scan_label="🛰️  Stop scanning" || scan_label="🔎  Start scanning"

  choice=$(
    {
      echo "$scan_label"
      echo "➕  Pair new device…"
      echo "❌  Disconnect all"
      [ -n "$paired" ]     && echo "$paired"
      [ -n "$discovered" ] && echo "$discovered"
    } | "${WOFI[@]}" --dmenu -i -p "Bluetooth"
  )

  [ -z "$choice" ] && break

  case "$choice" in
    "🔎  Start scanning")
      prep_scan_policy
      scan_on
      # give it a moment to discover
      sleep 2
      continue
      ;;
    "🛰️  Stop scanning")
      scan_off
      continue
      ;;
    "❌  Disconnect all")
      for mac in $(bt paired-devices | awk '/^Device/ {print $2}'); do bt disconnect "$mac"; done
      notify-send "Bluetooth" "Disconnected all paired devices"
      continue
      ;;
    "➕  Pair new device…")
      # Ensure scan running briefly for fresh list
      prep_scan_policy
      scan_on
      sleep 3
      discovered="$(list_discovered)"
      mac=$(
        { echo "⬅️  Back"; [ -n "$discovered" ] && echo "$discovered"; } |
        "${WOFI[@]}" --dmenu -i -p "Select device to pair" | awk '{print $2}'
      )
      [ -z "$mac" ] || [ "$mac" = "Back" ] && continue
      notify-send "Bluetooth" "Pairing $mac…"
      pair_trust_connect "$mac"
      continue
      ;;
    *)
      # Clicked a device line → toggle connect
      mac="$(echo "$choice" | awk '{print $2}')"
      [ -z "$mac" ] && continue
      toggle_connect "$mac"
      ;;
  esac
done

# Optional: stop scanning when menu exits
[ "$(is_scanning)" = "yes" ] && scan_off

