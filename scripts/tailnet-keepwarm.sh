#!/usr/bin/env bash
# tailnet-keepwarm.sh — keep the Tailscale path warm (auto-wake).
# Sends a tiny TCP SYN via tailnet every run; the client VM is outbound-only
# so the connection will fail, but the outbound packet keeps the relay
# mapping alive. This is the automated "wake" — no manual Telegram message
# needed after the wake theory was proven (see AGENTS.md).
#
# Replace 100.x.x.x with the tailnet IP of the machine on the other side.
set -uo pipefail
PEER_TAILNET_IP="100.x.x.x"  # <-- ganti dengan IP tailnet tujuan
timeout 8 bash -c "</dev/tcp/${PEER_TAILNET_IP}/22" 2>/dev/null || true
# Also touch the local tailnet interface to ensure tailscaled is active
timeout 5 tailscale ping --c=1 "${PEER_TAILNET_IP}" >/dev/null 2>&1 || true
exit 0
