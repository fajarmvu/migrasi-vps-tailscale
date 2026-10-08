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
- `systemd/vps-ssh-persistent.service` — koneksi SSH persisten ke mesin tujuan
  (auto-reconnect via `Restart=always` + `ServerAliveInterval`). Pelengkap
  monitoring berkala, bukan pengganti.

## 4. Laporan status

Gunakan token status yang sama seperti README agar konsisten:
`CUTOVER_SUMBER_SIAP` / `CUTOVER_GAGAL`, `CUE_AKTIF_SEMENTARA` /
`ROLLBACK_DIPERLUKAN`, `CUE_SIAP_PAKAI`, `MUSE_PASIF_SIAP_ROLLBACK` /
`MUSE_AKTIF_KEMBALI`, `CUE_PASIF_ROLLBACK`.

## 5. Troubleshooting (pelajaran dari lapangan, 2026-10-08)

### Tailscale SSH merebut port 22
- **Gejala:** SSH dijawab `SSH-2.0-Tailscale`, muncul
  `# Tailscale SSH requires an additional check` + URL login. Kunci SSH biasa
  tidak bisa dipakai.
- **Penyebab:** Tailscale SSH aktif di mesin tujuan dan mengalahkan OpenSSH.
- **Perbaikan (di mesin tujuan, akses langsung):**
  `tailscale set --ssh=false && systemctl enable --now ssh`,
  lalu pastikan `systemctl is-active ssh` = `active`.
- **Catatan:** untuk automation (bot/monitoring), OpenSSH lebih tepat daripada
  Tailscale SSH — Tailscale SSH butuh identitas interaktif, tidak kenal kunci
  otomasi. Jaringan Tailscale sendiri sudah privat, jadi OpenSSH di IP
  Tailscale sudah cukup aman.

### Jaringan VPS flapping (putus-nyambung)
- **Gejala:** SSH timeout + tunnel publik 502 bersamaan, tapi `uptime` mesin
  tidak reset (tidak reboot).
- **Diagnosis:** `uptime` hanya reset saat reboot — outage jaringan tidak
  mengubahnya. Koroborasi dengan jalur independen: (1) tunnel Cloudflare 502
  = tidak ada tunnel client yang terhubung; (2) log aplikasi di VPS menunjukkan
  VPS itu sendiri tidak bisa mencapai internet (mis. timeout ke api.telegram.org).
  Jika dua-duanya gagal bersamaan, masalahnya jaringan VPS, bukan probe.
- **Perbaikan:** butuh akses console/operator VPS — tidak bisa dari jarak jauh
  saat jaringan mati (chicken-and-egg). Setelah pulih, restart service yang
  sempat degradasi (mis. gateway) dan verifikasi ulang.

### Jebakan systemd pada unit SSH
- `%` di dalam unit file adalah specifier systemd — tulis `%%h %%p` agar ssh
  menerima `%h %p` untuk ProxyCommand.
- Di container tanpa user bus (`systemctl --user` gagal "No medium found"),
  pakai **system service**, bukan user service; `login linger` tidak relevan.
- Service di `/etc/systemd/system/` bisa hilang saat VM diganti total —
  monitoring berkala (cron) tetap diperlukan sebagai pengaman.
