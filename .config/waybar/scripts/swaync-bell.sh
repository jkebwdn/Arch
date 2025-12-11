#!/usr/bin/env bash
# Prints a bell (with unread count when available). Never empty.
if ! command -v swaync-client >/dev/null; then
  echo ""
  exit 0
fi

OUT="$(swaync-client -swb 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  # Fallback when daemon not ready / no output
  # Try JSON status to get count
  if command -v jq >/dev/null; then
    CNT="$(swaync-client -s 2>/dev/null | jq -r '.notification_count // 0' 2>/dev/null)"
    if [ -n "$CNT" ] && [ "$CNT" != "0" ]; then
      echo " $CNT"
    else
      echo ""
    fi
  else
    echo ""
  fi
else
  echo "$OUT"
fi
