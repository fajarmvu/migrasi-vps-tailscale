#!/usr/bin/env bash
# Validasi prasyarat sebelum migrasi dimulai.
# Dijalankan di mesin SUMBER. Berhenti dengan kode != 0 jika ada yang gagal.
set -euo pipefail

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  [OK]   $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [GAGAL] $1"; }

echo "== 1. Berkas konfigurasi =="
if [[ -f config.env ]]; then
  ok "config.env ditemukan"
  # shellcheck disable=SC1091
  source config.env
else
  fail "config.env tidak ada — salin dari config.env.example lalu isi"
fi

echo "== 2. Nilai konfigurasi terisi (tanpa placeholder) =="
for var in TS_NAME_MUSE TS_IP_MUSE TS_NAME_CUE TS_IP_CUE SSH_USER_CUE SSH_KEY; do
  val="${!var:-}"
  if [[ -z "$val" ]]; then
    fail "$var kosong"
  elif [[ "$val" == *"<"* || "$val" == *">"* || "$val" == "100.x.x.x" ]]; then
    fail "$var masih placeholder: $val"
  else
    ok "$var = $val"
  fi
done

echo "== 3. Perintah yang dibutuhkan =="
for cmd in ssh rsync tailscale; do
  if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd tersedia"; else fail "$cmd tidak ditemukan"; fi
done

echo "== 4. Kunci SSH migrasi =="
KEY_EXPANDED="${SSH_KEY/#\~/$HOME}"
if [[ -f "$KEY_EXPANDED" && -f "$KEY_EXPANDED.pub" ]]; then
  ok "kunci $KEY_EXPANDED (+ .pub) ada"
else
  fail "kunci $KEY_EXPANDED tidak ada — jalankan scripts/gen-migration-key.sh"
fi

echo "== 5. Tailscale =="
if tailscale status >/dev/null 2>&1; then
  ok "tailscaled berjalan"
  if tailscale status | grep -q "$TS_IP_CUE"; then
    ok "node tujuan $TS_NAME_CUE ($TS_IP_CUE) terlihat online"
  else
    fail "node tujuan $TS_IP_CUE tidak terlihat di tailscale status"
  fi
  if tailscale ping --c=2 "$TS_IP_CUE" >/dev/null 2>&1; then
    ok "tailscale ping ke tujuan berhasil"
  else
    fail "tailscale ping ke $TS_IP_CUE gagal"
  fi
else
  fail "tailscale status gagal — pastikan tailscaled aktif dan login"
fi

echo "== 6. SSH ke tujuan (tanpa password, batch mode) =="
if ssh -i "$KEY_EXPANDED" -o BatchMode=yes -o ConnectTimeout=10 \
     "$SSH_USER_CUE@$TS_IP_CUE" "echo ok" 2>/dev/null | grep -q ok; then
  ok "SSH ke $SSH_USER_CUE@$TS_IP_CUE berhasil"
else
  fail "SSH ke $SSH_USER_CUE@$TS_IP_CUE gagal — pasang public key dulu (Fase 3 README)"
fi

echo ""
echo "Hasil: $PASS lolos, $FAIL gagal."
[[ "$FAIL" -eq 0 ]]
