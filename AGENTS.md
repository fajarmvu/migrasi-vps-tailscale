# AGENTS.md — Instruksi untuk agent yang mengeksekusi migrasi

Repositori ini berisi playbook migrasi VM/VPS via Tailscale. Ada dua cara pakai:

- **Mode manusia (README.md):** perintah copy-paste untuk dua bot (Bot MUSE di
  mesin sumber, Bot CUE di mesin tujuan), dengan manusia sebagai perantara.
- **Mode agent (berkas ini):** kamu mengeksekusi langsung dari mesin sumber.
  Ikuti urutan fase di bawah; jangan melompat.

## 0. Prasyarat (wajib lolos sebelum mulai)

1. Salin `config.env.example` menjadi `config.env` dan isi SEMUA nilai asli
   (nama/IP Tailscale kedua mesin, user SSH tujuan, path kunci SSH).
2. Jalankan `./scripts/check-prereqs.sh` — semua cek harus `[OK]`.
   Jangan lanjut jika ada `[GAGAL]`.

## 1. Aturan keras (tidak boleh dilanggar)

- **Rahasia tidak pernah ditampilkan**: password, token, API key, private key
  SSH, atau isi berkas rahasia tidak boleh dicetak ke chat, log, atau commit.
  Public key SSH boleh ditampilkan.
- **Tidak ada dual-active**: bot polling, scheduler, worker tunggal, dan tunnel
  produksi hanya boleh hidup di SATU mesin dalam satu waktu.
- **Izin manusia wajib** sebelum: menghentikan layanan produksi, reboot,
  mengubah firewall, menghapus data, dan memulai cutover.
- **Jangan hapus mesin sumber** selama masa pengujian. Rollback harus selalu
  tersedia sampai migrasi dinyatakan final.

## 2. Urutan eksekusi (peta ke fase README.md)

| Tahap | Aksi | Bukti selesai |
|---|---|---|
| Audit sumber | Inventaris service, port, data, cron, tunnel (baca-saja) | Manifest tertulis |
| Tailscale | Kedua node online, ping dua arah | `tailscale status` + ping OK |
| SSH | Kunci migrasi dibuat; public key terpasang di tujuan | SSH batch-mode OK |
| Siapkan tujuan | Direktori, runtime, unit systemd (jangan start) | `systemd-analyze verify` OK |
| Salinan awal | rsync dry-run dulu, lalu salin; DB via dump/snapshot | checksum cocok |
| Cutover | Hentikan sumber → final sync → start tujuan berurutan | `CUE_AKTIF_SEMENTARA` |
| Verifikasi | Endpoint, data, log, akses publik; reboot bila disetujui | `CUE_SIAP_PAKAI` |
| Finalisasi | Sumber pasif, autostart lama dimatikan, rollback siap | `MUSE_PASIF_SIAP_ROLLBACK` |

Detail tiap fase ada di README.md. Jika tujuan gagal di fase mana pun,
jalankan prosedur rollback (tujuan berhenti dulu, sumber hidup setelahnya).

## 3. Template yang tersedia

- `scripts/gen-migration-key.sh` — buat kunci SSH ed25519 khusus migrasi.
- `scripts/vps-ssh.sh` — wrapper SSH via Tailscale ke mesin tujuan.
- `scripts/proxy-ssh-helper.py` — helper koneksi SSH (lihat README skrip).
- `scripts/check-prereqs.sh` — validasi prasyarat (wajib lolos).
- `systemd/` — template unit `app-gateway.service`, `model-router.service`,
  `tunnel@.service`. Ganti placeholder `<USER>`, `<APP_DIR>`, `<PORT>`,
  `<EXEC_START>` sebelum dipakai.

## 4. Laporan status

Gunakan token status yang sama seperti README agar konsisten:
`CUTOVER_SUMBER_SIAP` / `CUTOVER_GAGAL`, `CUE_AKTIF_SEMENTARA` /
`ROLLBACK_DIPERLUKAN`, `CUE_SIAP_PAKAI`, `MUSE_PASIF_SIAP_ROLLBACK` /
`MUSE_AKTIF_KEMBALI`, `CUE_PASIF_ROLLBACK`.
