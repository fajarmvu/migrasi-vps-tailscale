#!/bin/bash
# notify.sh — Send notification to Fajar (token-free).
# Priority: 1) Telegram Bot API (if tg-notify-bot.conf configured),
#           2) fallback: his own Saved Messages via Telethon user session.
# Usage: notify.sh "<message>"
set -u
BASE="$HOME/workspace/hermuse/tg-monitor"
MSG="${1:-test}"

# 1) Bot API (needs tg-notify-bot.conf with BOT_TOKEN=... and CHAT_ID=...)
if [ -f "$BASE/tg-notify-bot.conf" ]; then
  # shellcheck disable=SC1091
  . "$BASE/tg-notify-bot.conf"
  if [ -n "${BOT_TOKEN:-}" ] && [ -n "${CHAT_ID:-}" ]; then
    if timeout 20 curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d "chat_id=${CHAT_ID}" -d "text=${MSG}" -d "parse_mode=" \
      --proxy "${HTTPS_PROXY:-}" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "^200$"; then
      echo "NOTIFY_SENT_BOTAPI"
      exit 0
    fi
  fi
fi

# 2) Fallback: Saved Messages via Telethon (his own account)
"$BASE/venv/bin/python" - "$MSG" << 'PYEOF' 2>/dev/null
import asyncio, configparser, os, sys
BASE = os.path.expanduser("~/workspace/hermuse/tg-monitor")
def load_conf():
    c = configparser.ConfigParser()
    with open(os.path.join(BASE, "tg-api.conf")) as f:
        c.read_string("[tg]\n" + f.read())
    return c["tg"]["api_id"], c["tg"]["api_hash"]
async def main(msg):
    from telethon import TelegramClient
    from urllib.parse import urlparse
    api_id, api_hash = load_conf()
    proxy = None
    pu = os.environ.get("HTTPS_PROXY", "")
    if pu:
        p = urlparse(pu)
        proxy = ("http", p.hostname, p.port or 3128, True, p.username, p.password)
    client = TelegramClient(os.path.join(BASE, "gladis.session"), int(api_id), api_hash,
                            proxy=proxy, timeout=20)
    try:
        await asyncio.wait_for(client.connect(), timeout=30)
        if not await client.is_user_authorized():
            print("NOT_AUTHORIZED"); return 1
        await client.send_message("me", msg)
        print("NOTIFY_SENT_SAVED")
        return 0
    except Exception as e:
        print(f"ERROR: {type(e).__name__}")
        return 2
    finally:
        await client.disconnect()
sys.exit(asyncio.run(main(sys.argv[1])))
PYEOF
