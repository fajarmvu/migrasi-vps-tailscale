#!/usr/bin/env python3
"""
wake.py — Send wake-up message to @manus_ai_agent_bot via Telethon (user account).
Token-free: no AI, no browser. Uses the authenticated gladis.session.
Usage: wake.py "<message>"
"""
import asyncio, configparser, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
BOT = "manus_ai_agent_bot"

def load_conf():
    c = configparser.ConfigParser()
    with open(os.path.join(BASE, "tg-api.conf")) as f:
        content = "[tg]\n" + f.read()
    c.read_string(content)
    return c["tg"]["api_id"], c["tg"]["api_hash"]

def make_client():
    from telethon import TelegramClient
    from urllib.parse import urlparse
    api_id, api_hash = load_conf()
    proxy = None
    pu = os.environ.get("HTTPS_PROXY", "")
    if pu:
        p = urlparse(pu)
        proxy = ("http", p.hostname, p.port or 3128, True, p.username, p.password)
    return TelegramClient(
        os.path.join(BASE, "gladis.session"), int(api_id), api_hash,
        proxy=proxy, connection_retries=3, retry_delay=2, timeout=20,
    )

async def main(message):
    client = make_client()
    try:
        await asyncio.wait_for(client.connect(), timeout=30)
        if not await client.is_user_authorized():
            print("NOT_AUTHORIZED")
            return 1
        await client.send_message(BOT, message)
        print("WAKE_SENT")
        return 0
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")
        return 2
    finally:
        await client.disconnect()

if __name__ == "__main__":
    msg = sys.argv[1] if len(sys.argv) > 1 else (
        "Hi, my sandbox VM named 'Muse' on the Cue platform seems to be asleep — "
        "SSH over Tailscale is unreachable. Could you please check/wake it? Thank you!"
    )
    sys.exit(asyncio.run(main(msg)))
