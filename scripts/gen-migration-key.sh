#!/usr/bin/env bash
# Membuat kunci SSH khusus migrasi di mesin SUMBER.
# Hanya kunci PUBLIK (.pub) yang diteruskan ke mesin tujuan.
set -euo pipefail
KEY="$HOME/.ssh/migrasi_$(date +%Y%m%d)"
ssh-keygen -t ed25519 -f "$KEY" -N "" -C "kunci-migrasi"
chmod 600 "$KEY"
echo "Kunci privat : $KEY  (JANGAN dibagikan)"
echo "Kunci publik : $KEY.pub (teruskan ke Bot CUE)"
