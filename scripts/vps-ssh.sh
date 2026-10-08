#!/usr/bin/env bash
# SSH ke mesin tujuan melalui alamat Tailscale.
# Ganti DEST_IP dengan IP Tailscale mesin tujuan, DEST_USER dengan user-nya.
set -euo pipefail
DEST_USER="${DEST_USER:-ubuntu}"
DEST_IP="${DEST_IP:-<IP_TAILSCALE_TUJUAN>}"
exec ssh -i "$HOME/.ssh/migrasi_*" -o StrictHostKeyChecking=accept-new \
  "$DEST_USER@$DEST_IP" "$@"
