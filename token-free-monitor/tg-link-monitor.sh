#!/bin/bash
# tg-link-monitor.sh — Token-free VPS link monitor (no AI tokens).
# Runs via systemd timer every 2 minutes.
#
# Flow:
#   1. SSH probe to Muse By Cue (single attempt, fast timeout).
#   2. Track state in files (up/down, streak).
#   3. On DOWN: send wake-up via Telethon (wake.py) to @manus_ai_agent_bot
#      on first detection, re-send every 10 min while still down.
#   4. On recovery: log it.
#   5. User notifications go via notify.sh (Telegram Bot API, token-free).
#
# State files live in the same hidden_files dir as the AI keepalive so both
# systems share state and don't double-notify.

set -u
BASE="$HOME/workspace/hermuse/tg-monitor"
HF="$HOME/workspace/goals/hermuse-telegram-bot-on-vm/hidden_files"
VPS_SSH="$HOME/workspace/hermuse/vps-ssh.sh"
LOG="$HF/tg-monitor.log"

log() { echo "[$(TZ=Asia/Jakarta date '+%F %H:%M:%S')] $*" >> "$LOG"; }

# ---- 0. self-heal: SSH service + proxy creds (same as AI keepalive step 0) ----
if [ ! -f /etc/systemd/system/vps-cue-ssh.service ]; then
  cp "$HOME/workspace/hermuse/vps-cue-ssh.service.template" /etc/systemd/system/vps-cue-ssh.service 2>/dev/null
  chmod 600 /etc/systemd/system/vps-cue-ssh.service 2>/dev/null
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now vps-cue-ssh.service 2>/dev/null
  log "SELF-HEAL: rebuilt vps-cue-ssh.service from template"
fi
if [ -n "${HTTPS_PROXY:-}" ]; then
  stored=""
  [ -f "$HOME/.config/vps-ssh-proxy-env" ] && stored=$(cat "$HOME/.config/vps-ssh-proxy-env" 2>/dev/null)
  live="HTTPS_PROXY=$HTTPS_PROXY"
  # stored file may be bare URL or VAR=URL; normalize compare on the URL part
  if [ "$stored" != "$live" ] && [ "$stored" != "$HTTPS_PROXY" ]; then
    echo "$live" > "$HOME/.config/vps-ssh-proxy-env"
    chmod 600 "$HOME/.config/vps-ssh-proxy-env"
    if [ "$(systemctl is-active vps-cue-ssh.service 2>/dev/null)" != "active" ]; then
      systemctl restart vps-cue-ssh.service 2>/dev/null
      log "SELF-HEAL: proxy creds rotated, service restarted"
    else
      log "SELF-HEAL: proxy creds refreshed (service still active)"
    fi
  fi
fi

# ---- 1. SSH probe (single fast attempt) ----
result=$(timeout 20 bash "$VPS_SSH" "echo VPS-OK" 2>&1 | head -1)
prev_state="unknown"
[ -f "$HF/vps-link-state" ] && prev_state=$(cat "$HF/vps-link-state")
streak=0
[ -f "$HF/vps-link-down-streak" ] && streak=$(cat "$HF/vps-link-down-streak" 2>/dev/null || echo 0)

if [ "$result" = "VPS-OK" ]; then
  # ---- UP ----
  echo "up" > "$HF/vps-link-state"
  echo "0" > "$HF/vps-link-down-streak"
  echo "0" > "$HF/vps-link-alerted"
  rm -f "$HF/vps-telegram-wake-requested" "$HF/tg-wake-sent"
  if [ "$prev_state" = "down" ]; then
    log "RECOVERY: link UP (was down, streak was $streak)"
    "$BASE/notify.sh" "✅ Link VPS Gladis → Muse By Cue pulih! (sempat pedot, streak $streak)" 2>/dev/null || true
  fi
  log "up"
else
  # ---- DOWN ----
  streak=$((streak + 1))
  echo "down" > "$HF/vps-link-state"
  echo "$streak" > "$HF/vps-link-down-streak"
  log "down (streak=$streak, err=${result:0:60})"
  # Wake-up via Telethon to @manus_ai_agent_bot.
  # Fajar 2026-10-09: re-send every 10 min while still down (don't leave it dead).
  # tg-wake-sent holds the timestamp of the last sent wake-up.
  last_wake=""
  [ -f "$HF/tg-wake-sent" ] && last_wake=$(cat "$HF/tg-wake-sent" 2>/dev/null || echo "")
  now_epoch=$(date +%s)
  last_epoch=0
  if [ -n "$last_wake" ]; then
    # tg-wake-sent is written with TZ=Asia/Jakarta (see line above), so it must
    # be parsed in the same TZ; system clock is UTC (VM replacement sets no
    # local TZ), otherwise the epoch lands 7h in the future and the 10-min
    # re-send never fires.
    last_epoch=$(TZ=Asia/Jakarta date -d "$last_wake" +%s 2>/dev/null || echo 0)
  fi
  elapsed=$((now_epoch - last_epoch))
  if [ -z "$last_wake" ] || [ "$elapsed" -ge 600 ]; then
    log "WAKE: sending wake-up via Telethon to @manus_ai_agent_bot (elapsed ${elapsed}s)"
    if "$BASE/venv/bin/python" "$BASE/wake.py" "Hi, my sandbox VM named 'Muse' on the Cue platform seems to be asleep — SSH over Tailscale is unreachable (probe: ${result:0:50}, down streak $streak). Tailscale logs previously showed 'slept ... probably wake from sleep'. Could you please check/wake it? Thank you!" >> "$LOG" 2>&1; then
      echo "$(TZ=Asia/Jakarta date '+%F %H:%M')" > "$HF/tg-wake-sent"
      log "WAKE: sent OK"
    else
      log "WAKE: FAILED (telethon error)"
    fi
  fi
  # User alert at streak >= 5 (~10 min at 2-min interval), once per outage
  alerted="0"
  [ -f "$HF/vps-link-alerted" ] && alerted=$(cat "$HF/vps-link-alerted" 2>/dev/null || echo 0)
  if [ "$streak" -ge 5 ] && [ "$alerted" != "1" ]; then
    echo "1" > "$HF/vps-link-alerted"
    log "ALERT: outage >=10min, notifying user"
    "$BASE/notify.sh" "🔴 Link SSH VPS Gladis → Muse By Cue pedot ~10 menit. Wake-up via bot wis dikirim. Error: ${result:0:60}" 2>/dev/null || true
  fi
fi
exit 0
