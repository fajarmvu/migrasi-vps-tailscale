#!/usr/bin/env python3
"""Combined auth: request code + sign in (single session flow)."""
import asyncio, configparser, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))

def load_conf():
    c = configparser.ConfigParser()
    with open(os.path.join(BASE, "tg-api.conf")) as f:
        content = "[tg]\n" + f.read()
    c.read_string(content)
    return c["tg"]["api_id"], c["tg"]["api_hash"], c["tg"]["phone"]

def make_client():
    from telethon import TelegramClient
    from urllib.parse import urlparse
    api_id, api_hash, _ = load_conf()
    proxy = None
    pu = os.environ.get("HTTPS_PROXY", "")
    if pu:
        p = urlparse(pu)
        proxy = ("http", p.hostname, p.port or 3128, True, p.username, p.password)
    return TelegramClient(
        os.path.join(BASE, "gladis.session"), int(api_id), api_hash,
        proxy=proxy, connection_retries=3, retry_delay=2, timeout=20,
    )

async def step1():
    """Request a fresh code (call this first, then ask user for the code)."""
    from telethon import TelegramClient
    _, _, phone = load_conf()
    client = make_client()
    await asyncio.wait_for(client.connect(), timeout=30)
    if await client.is_user_authorized():
        print("ALREADY_AUTHORIZED")
    else:
        sent = await client.send_code_request(phone)
        # persist the hash so step2 can use the SAME code request
        with open(os.path.join(BASE, "phone_code_hash.txt"), "w") as f:
            f.write(sent.phone_code_hash)
        print("CODE_SENT")
    await client.disconnect()

async def step2(code):
    """Sign in with the code using the saved phone_code_hash from step1."""
    _, _, phone = load_conf()
    hash_file = os.path.join(BASE, "phone_code_hash.txt")
    if not os.path.exists(hash_file):
        print("ERROR: no phone_code_hash.txt — run step1 (request) first")
        return
    with open(hash_file) as f:
        phone_code_hash = f.read().strip()
    client = make_client()
    await asyncio.wait_for(client.connect(), timeout=30)
    try:
        if await client.is_user_authorized():
            print("ALREADY_AUTHORIZED")
        else:
            await asyncio.wait_for(
                client.sign_in(phone, code, phone_code_hash=phone_code_hash),
                timeout=30,
            )
            print("AUTHORIZED_OK" if await client.is_user_authorized() else "SIGNIN_FAILED")
        me = await client.get_me()
        print(f"LOGGED_IN_AS={me.first_name} id={me.id}")
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")
    finally:
        await client.disconnect()

if __name__ == "__main__":
    if sys.argv[1] == "request":
        asyncio.run(step1())
    else:
        asyncio.run(step2(sys.argv[1]))
