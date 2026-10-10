# Token-Free VPS Link Monitor

Monitoring link SSH **tanpa token AI** — 100% bash + Python + systemd.

## Arsitektur

```
systemd timer (tiap 2 menit)
  → tg-link-monitor.sh (bash: SSH probe + state tracking)
      → DOWN: wake.py (Telethon → bot platform via akun Telegram user; kirim ulang tiap 10 menit selama masih down)
      → DOWN ≥10 mnt: notify.sh (peringatan ke user)
      → UP kembali: notify.sh (notifikasi pulih)
```

## File

| File | Fungsi |
|------|--------|
| `tg-link-monitor.sh` | Probe SSH, kelola state, self-heal service/proxy |
| `wake.py` | Kirim wake-up ke bot platform via Telethon (MTProto, akun user) |
| `notify.sh` | Notifikasi ke user (Bot API → fallback Saved Messages) |
| `auth.py` | Autentikasi sesi Telethon (sekali saja) |
| `tg-link-monitor.service` | Unit systemd (oneshot) |
| `tg-link-monitor.timer` | Timer systemd (tiap 2 menit) |

## Setup

1. Install Telethon: `python3 -m venv venv && venv/bin/pip install telethon python-socks`
2. Buat `tg-api.conf` (chmod 600):
   ```
   api_id=<dari my.telegram.org>
   api_hash=<dari my.telegram.org>
   phone=+62xxxx
   ```
3. Autentikasi: `venv/bin/python auth.py request` → masukkan kode → `venv/bin/python auth.py <kode>`
4. Install unit: `cp tg-link-monitor.{service,timer} /etc/systemd/system/ && systemctl enable --now tg-link-monitor.timer`

## Catatan

- MTProto butuh proxy jika TCP langsung diblokir — script otomatis pakai `$HTTPS_PROXY`.
- File rahasia (`tg-api.conf`, `gladis.session`, `phone_code_hash.txt`) **jangan** di-commit.
- Dibuat 2026-10-09 — menggantikan cron AI `vps-cue-keepalive` untuk monitoring.
