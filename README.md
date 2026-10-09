Panduan operasional sederhana · Versi 2.0

# Muse Migrate To Cue Manus
Urutan perintah yang dapat langsung disalin ke dua bot: mulai dari persiapan, menghubungkan Tailscale, memindahkan layanan, sampai sistem baru siap digunakan.

> **Untuk agent otomatis:** baca `AGENTS.md` — instruksi eksekusi langsung
> (isi `config.env`, jalankan `scripts/check-prereqs.sh`, ikuti fase berurutan).
> README ini adalah panduan mode manusia (dua bot + perantara).
Bot MUSE
mengelola mesin lama
→
Bot CUE
mengelola mesin baru

Contoh istilah: MUSE = sumber · CUE = tujuan. Nama dapat diganti untuk VM/VPS lain.
8 Oktober 2026
Cara menggunakan panduanMUSE → CUE

## Anda cukup menjadi penghubung antara dua bot

Setiap bot hanya mengerjakan mesin yang dikendalikannya. Anda menyalin perintah dari panduan ini, lalu meneruskan hasil penting dari satu bot kepada bot lainnya.
1. Perintah ke Bot MUSE
→2. Salin hasil penting
→3. Perintah ke Bot CUE

### Yang Anda lakukan

- Mengirim perintah sesuai urutan.

- Membuka tautan persetujuan Tailscale.

- Menyalin nama host, IP Tailscale, dan kunci publik.

- Menyetujui waktu pemutusan layanan.

### Yang dikerjakan bot

- Memeriksa mesin dan dependensi.

- Memasang serta menguji Tailscale.

- Menyalin data dan menyiapkan systemd.

- Menguji layanan dan menyiapkan rollback.

### Aturan wajib sejak awal
Jangan pernah dikirim melalui chat
Password, token bot, API key, private key SSH, cookie, atau isi lengkap berkas rahasia. Bot boleh memindahkannya langsung antarmesin melalui SSH, tetapi tidak boleh menampilkannya.

- Jangan hapus data atau mesin lama selama masa pengujian.

- Jangan menyalakan bot polling, scheduler, worker antrean, atau tunnel yang sama pada dua mesin sekaligus.

- Bot harus meminta izin sebelum menghentikan layanan, melakukan reboot, mengubah firewall, atau menghapus data.

### Daftar isi singkat
FaseHasil1-2Persiapan dan Tailscale tersambung3-5SSH, inventaris, dan salinan awal siap6-7Cutover, verifikasi, dan finalisasiDaruratRollback tanpa dual-activeIkuti urutan; jangan melompati tahap verifikasi02
Fase 1 · PersiapanBelum ada perubahan layanan

## Mulai dengan pemeriksaan aman pada kedua mesin
KIRIM KE BOT MUSE
Saya akan memigrasikan seluruh stack dari mesin ini ke VPS tujuan. Untuk saat ini, hanya lakukan pemeriksaan baca-saja. Jangan menghentikan service, jangan mengubah firewall, jangan reboot, dan jangan menampilkan rahasia. Laporkan secara ringkas: 1. hostname, sistem operasi, arsitektur, CPU, RAM, disk, dan uptime; 2. semua service aplikasi yang sedang aktif; 3. port yang dipakai; 4. direktori aplikasi, database, konfigurasi, dan data persisten; 5. cron, timer, watchdog, tunnel, dan bot polling; 6. versi runtime utama; 7. cara backup dan cara rollback yang disarankan.

KIRIM KE BOT CUE
Mesin ini akan menjadi tujuan migrasi. Untuk saat ini, hanya lakukan pemeriksaan baca-saja. Jangan mengubah firewall, jangan reboot, dan jangan menghapus apa pun. Laporkan secara ringkas: 1. hostname, sistem operasi, arsitektur, CPU, RAM, disk, dan uptime; 2. user Linux yang dapat dipakai untuk migrasi; 3. apakah sudo/root, OpenSSH, systemd, curl, rsync, dan ruang disk tersedia; 4. service atau port yang berpotensi bentrok; 5. akses konsol provider atau jalur pemulihan yang tersedia.

Lanjut jika
Kapasitas tujuan cukup, arsitektur/runtime kompatibel, akses sudo tersedia, port tidak bentrok, dan kedua bot menyatakan pemeriksaan selesai tanpa perubahan berbahaya.
Fase 1 · inventaris awal03
Fase 2 · TailscaleSambungkan kedua mesin

## Masukkan MUSE dan CUE ke tailnet yang sama

Gunakan akun Tailscale yang sama. Bila bot memberikan tautan persetujuan, buka tautan tersebut sendiri dan setujui node yang benar. Jangan memberikan password akun kepada bot.
1 · KIRIM KE BOT CUE
Pasang dan aktifkan Tailscale pada VPS ini. Gunakan hostname Tailscale yang jelas, misalnya `vps-cue`. Jika autentikasi memerlukan tautan persetujuan, kirimkan tautannya kepada saya dan berhenti sampai saya menyetujuinya. Jangan meminta atau menampilkan auth key. Setelah disetujui, aktifkan autostart lalu laporkan nama node, IP Tailscale, status koneksi, dan hasil netcheck.

2 · KIRIM KE BOT MUSE
Pasang atau periksa Tailscale pada VM ini. Gunakan hostname yang jelas, misalnya `vm-muse`. Jika autentikasi memerlukan tautan persetujuan, kirimkan tautannya kepada saya dan berhenti sampai saya menyetujuinya. Jangan meminta atau menampilkan auth key. Setelah disetujui, aktifkan autostart lalu laporkan nama node, IP Tailscale, status koneksi, dan hasil netcheck.

Yang Anda teruskan
Catat hasil berikut tanpa rahasia: NAMA_MUSE, IP_TS_MUSE, NAMA_CUE, dan IP_TS_CUE.
3 · KIRIM KE BOT MUSE
Target migrasi sudah masuk ke tailnet yang sama. Nama target: `[NAMA_CUE]` IP Tailscale target: `[IP_TS_CUE]` Periksa apakah target terlihat di status Tailscale, lalu lakukan Tailscale ping ke nama dan IP tersebut. Jangan lanjut ke SSH sebelum ping berhasil. Laporkan hasilnya.

4 · KIRIM KE BOT CUE
Sumber migrasi sudah masuk ke tailnet yang sama. Nama sumber: `[NAMA_MUSE]` IP Tailscale sumber: `[IP_TS_MUSE]` Periksa apakah sumber terlihat di status Tailscale, lalu lakukan Tailscale ping ke nama dan IP tersebut. Jangan mengubah firewall. Laporkan hasilnya.

Tanda berhasil
Kedua node terlihat online dan ping dua arah berhasil. Jalur direct lebih baik, tetapi relay tetap dapat dipakai untuk melanjutkan bila stabil.
Fase 2 · jaringan privat siap04
Fase 3 · SSH privatBerikan akses minimum

## Hubungkan MUSE ke CUE tanpa membagikan private key
1 · KIRIM KE BOT MUSE
Buat kunci SSH khusus migrasi jika belum ada. Jangan menimpa kunci lama. Simpan private key hanya di mesin ini dengan izin yang aman. Tampilkan hanya public key dan fingerprint-nya agar dapat saya teruskan ke Bot CUE. Jangan mencoba login sebelum saya memberi user tujuan.

Salin hanya baris public key
Kunci publik biasanya diawali ssh-ed25519. Jangan pernah menyalin berkas private key atau teks yang diawali -----BEGIN ... PRIVATE KEY-----.
2 · KIRIM KE BOT CUE
Siapkan user Linux khusus atau user yang sesuai untuk menerima migrasi melalui SSH di alamat Tailscale. Tambahkan public key berikut ke `authorized_keys` dengan izin direktori dan berkas yang benar: `[TEMPEL PUBLIC KEY DARI BOT MUSE]` Jangan menonaktifkan akses lama, jangan menutup SSH publik, dan jangan mengubah firewall dahulu. Laporkan username tujuan, home directory, IP Tailscale, serta fingerprint key yang dipasang.

3 · KIRIM KE BOT MUSE
Uji SSH melalui Tailscale ke target berikut: User: `[USER_CUE]` Host/IP: `[IP_TS_CUE]` Cocokkan fingerprint host dengan informasi dari Bot CUE. Jalankan hanya pemeriksaan aman: hostname, id, uptime, ruang disk, dan kemampuan sudo noninteraktif bila tersedia. Jangan menyalin data dulu. Laporkan apakah SSH dan izin tujuan siap.

Berhenti jika
Fingerprint tidak cocok, SSH meminta password yang tidak diharapkan, user salah, atau akses menuju host selain IP Tailscale tujuan.
Fase 3 · SSH privat teruji05
Fase 4 · Rencana migrasiBot menyusun pekerjaan

## Minta Bot MUSE membuat manifest, lalu teruskan ringkasannya
1 · KIRIM KE BOT MUSE
SSH ke Bot CUE sudah teruji. Sekarang buat manifest migrasi lengkap, tetapi belum melakukan cutover. Manifest harus memuat: - service, urutan start/stop, dan kebutuhan autostart; - direktori aplikasi, data persisten, database, config, dan environment file; - runtime/paket yang harus ada di tujuan; - port lokal, endpoint pemeriksaan, tunnel/reverse proxy; - cron, timer, watchdog, bot polling, dan worker tunggal; - metode backup konsisten untuk database; - estimasi ruang data, daftar pengecualian cache/log sementara; - urutan salinan awal, final sync, verifikasi, dan rollback. Jangan tampilkan nilai rahasia. Simpan manifest di mesin sumber dan kirim ringkasan yang aman untuk saya teruskan.

2 · KIRIM KE BOT CUE BERSAMA RINGKASAN MANIFEST
Berikut ringkasan manifest dari Bot MUSE: `[TEMPEL RINGKASAN MANIFEST TANPA RAHASIA]` Siapkan mesin tujuan sesuai manifest: user service, direktori, ownership, runtime, paket, ruang disk, dan unit systemd. Jangan membuat ulang nilai rahasia; rahasia akan dipindahkan langsung melalui SSH. Jangan menyalakan bot polling, scheduler, worker tunggal, atau tunnel produksi. Uji syntax unit dan laporkan apa yang siap, apa yang masih kurang, serta konflik yang ditemukan.

### Keputusan sebelum penyalinan

- Bot CUE menyatakan runtime dan direktori siap.

- Nama service tujuan sudah diketahui.

- Database mempunyai metode backup konsisten.

- Daftar proses yang tidak boleh dual-active sudah jelas.

- Perintah rollback telah ditulis oleh Bot MUSE.
Jangan terburu-buru
Jika Bot CUE menemukan versi runtime berbeda, arsitektur tidak cocok, atau port bentrok, selesaikan terlebih dahulu. Jangan memaksa menyalin biner dari arsitektur lain.
Fase 4 · tujuan siap menerima data06
Fase 5 · Salinan awalSumber tetap melayani

## Salin sebagian besar data sebelum downtime
1 · KIRIM KE BOT MUSE
Lakukan salinan awal ke Bot CUE melalui SSH Tailscale. Sumber tetap aktif. Ketentuan: 1. gunakan dry-run terlebih dahulu dan laporkan ringkasannya; 2. setelah aman, salin aplikasi, data persisten, unit service, dan konfigurasi yang diperlukan; 3. jangan menyalin cache, log besar, PID, socket, atau file sementara; 4. untuk database aktif, gunakan snapshot/dump konsisten; jangan menyalin file database yang sedang ditulis secara mentah; 5. rahasia boleh dipindahkan langsung antarmesin, tetapi jangan dicetak ke chat atau log; 6. jangan menggunakan opsi hapus di tujuan; 7. verifikasi jumlah file, ukuran, checksum penting, ownership, dan izin. Setelah selesai, laporkan apa yang tersalin, apa yang sengaja belum tersalin, dan tindakan yang masih dibutuhkan saat final sync.

2 · KIRIM KE BOT CUE SETELAH SALINAN AWAL
Periksa hasil salinan awal tanpa menyalakan service produksi. Verifikasi direktori, ownership, permission, runtime, konfigurasi, database hasil snapshot/dump, unit systemd, serta kecukupan ruang disk. Lakukan pemeriksaan syntax dan uji lokal yang tidak memicu polling, scheduler, worker, atau tunnel. Jangan menampilkan rahasia. Laporkan status siap/tidak siap dan daftar masalah.

Lanjut ke cutover jika
Bot MUSE menyatakan salinan awal lengkap dan Bot CUE menyatakan layanan dapat dimulai setelah final sync tanpa perubahan tambahan yang belum diuji.
Belum waktunya
Jangan mematikan MUSE hanya karena file sudah ada di CUE. Cutover baru dilakukan setelah kedua bot memberikan status siap.
Fase 5 · data awal tersedia di tujuan07
Fase 6 · CutoverIkuti urutan tanpa jeda improvisasi

## Hentikan sumber, final sync, lalu nyalakan tujuan
Persetujuan berdampak
Tahap ini menimbulkan downtime singkat. Pastikan Anda masih mempunyai akses ke kedua bot dan konsol provider. Jangan menjalankan langkah kedua sebelum langkah pertama dinyatakan selesai.
1 · KIRIM KE BOT MUSE
Mulai cutover sekarang. Lakukan sesuai manifest dan berhenti jika ada kegagalan: 1. catat status terakhir dan buat backup final yang konsisten; 2. hentikan seluruh bot polling, scheduler, worker tunggal, tunnel, dan service aplikasi sumber dalam urutan aman; 3. pastikan proses benar-benar berhenti dan port sudah bebas; 4. lakukan final sync ke Bot CUE melalui SSH Tailscale, tanpa menghapus backup tujuan; 5. verifikasi data, database, ownership, permission, dan checksum penting; 6. jangan menyalakan service tujuan dan jangan menonaktifkan autostart sumber secara permanen dahulu. Laporkan hanya salah satu hasil: `CUTOVER_SUMBER_SIAP` beserta ringkasan verifikasi, atau `CUTOVER_GAGAL` beserta titik kegagalannya.

Checkpoint
Lanjutkan hanya jika jawaban Bot MUSE secara tegas berisi CUTOVER_SUMBER_SIAP. Jika gagal, minta Bot MUSE mengembalikan layanan sumber sesuai rencana rollback.
2 · KIRIM KE BOT CUE
Bot MUSE telah menyelesaikan final sync dan semua konsumen tunggal di sumber sudah berhenti. Mulai layanan tujuan sesuai urutan manifest: 1. muat ulang unit systemd; 2. aktifkan dan mulai service inti; 3. uji endpoint lokal dan data; 4. setelah inti sehat, mulai tunnel/reverse proxy; 5. terakhir, mulai bot polling, scheduler, dan worker tunggal; 6. periksa status, port, log terbaru, koneksi publik, dan jumlah koneksi yang relevan. Jika ada kegagalan kritis, hentikan kembali seluruh service tujuan dan laporkan `ROLLBACK_DIPERLUKAN`. Jika berhasil, laporkan `CUE_AKTIF_SEMENTARA` beserta bukti ringkas.

3 · KIRIM KE BOT MUSE
CUE sudah aktif sementara. Pastikan semua service aplikasi, tunnel, bot polling, scheduler, worker, dan watchdog lama di MUSE tetap berhenti. Jangan hapus data dan jangan menonaktifkan rollback dahulu. Pantau apakah ada proses yang bangkit otomatis, lalu laporkan status MUSE pasif.

Fase 6 · hanya satu mesin yang aktif08
Fase 7 · VerifikasiJangan percaya status active saja

## Buktikan CUE benar-benar siap digunakan
1 · KIRIM KE BOT CUE
Lakukan verifikasi penerimaan menyeluruh: - semua service yang diharapkan aktif dan tidak crash-loop; - port lokal mendengarkan pada alamat yang benar; - endpoint memberi respons nyata, bukan hanya status proses; - data/database dapat dibaca dan jumlah objek penting sesuai; - bot menerima koneksi tanpa konflik polling; - tunnel atau akses publik bekerja; - cron/timer yang dibutuhkan aktif satu kali saja; - log terbaru bersih dari error kritis; - resource CPU, RAM, dan disk normal. Setelah itu, lakukan reboot terkontrol hanya jika saya menyetujuinya. Sesudah reboot, ulangi pemeriksaan autostart dan endpoint. Laporkan `CUE_SIAP_PAKAI` hanya jika semua lulus.

Persetujuan reboot
Jika Bot CUE meminta persetujuan, jawab: “Saya setuju reboot terkontrol. Setelah kembali online, ulangi seluruh verifikasi dan jangan mengubah firewall.”
2 · KIRIM KE BOT MUSE SETELAH CUE SIAP PAKAI
Bot CUE telah dinyatakan `CUE_SIAP_PAKAI`. Finalisasi mesin lama sebagai sumber cadangan pasif: 1. nonaktifkan autostart service aplikasi, bot, scheduler, worker, tunnel, dan watchdog lama; 2. jangan hapus aplikasi, data, backup, atau konfigurasi; 3. pastikan tidak ada proses yang aktif dan port aplikasi tidak mendengarkan; 4. simpan catatan rollback dan batas waktu retensi; 5. laporkan status akhir `MUSE_PASIF_SIAP_ROLLBACK`.

### Checklist akhir

- CUE lulus reboot dan autostart.

- Endpoint lokal dan publik merespons.

- Tidak ada dual-active.

- MUSE pasif dan tidak dapat bangkit otomatis.

- Backup serta rollback masih tersedia.
Fase 7 · migrasi selesai09
Darurat · RollbackGunakan jika tujuan gagal

## Kembalikan layanan tanpa membuat dua sistem aktif

Urutan rollback adalah kebalikan cutover. CUE harus berhenti terlebih dahulu; MUSE baru boleh diaktifkan setelah CUE benar-benar pasif.
1 · KIRIM KE BOT CUE
Lakukan rollback sisi tujuan. Hentikan bot polling, scheduler, worker, tunnel, lalu service aplikasi dalam urutan aman. Pastikan proses berhenti dan port bebas. Jangan hapus data atau backup. Laporkan `CUE_PASIF_ROLLBACK` hanya setelah semua konsumen tunggal benar-benar berhenti.

Checkpoint
Jangan menyalakan MUSE sebelum Bot CUE menyatakan CUE_PASIF_ROLLBACK.
2 · KIRIM KE BOT MUSE
Bot CUE telah menyatakan `CUE_PASIF_ROLLBACK`. Pulihkan layanan sumber dari kondisi terakhir yang konsisten. Aktifkan service inti lebih dahulu, uji data dan endpoint lokal, lalu mulai tunnel, bot polling, scheduler, serta worker tunggal. Periksa status, port, log, dan akses publik. Laporkan `MUSE_AKTIF_KEMBALI` hanya jika semua lulus.

### Setelah layanan pulih

- Jangan menghapus data di CUE; simpan untuk analisis kegagalan.

- Catat langkah yang gagal, pesan error, dan perubahan terakhir.

- Perbaiki CUE dalam keadaan pasif, lalu ulangi dari salinan awal.

### Diagnosis koneksi dalam urutan yang benar
GejalaMinta bot memeriksaNode tidak terlihattailscaled, login tailnet, status node, waktu sistemPing gagalstatus Tailscale, netcheck, policy/ACL, rutePing berhasil, SSH gagalsshd, user, public key, permission, port 22SSH berhasil, layanan gagalruntime, environment, ownership, database, journalLokal sehat, publik gagaltunnel/reverse proxy, target port, DNS, kredensial tunnelRollback aman · tujuan berhenti sebelum sumber hidup10
Ringkasan satu halamanUrutan copy-paste

## Dari nol sampai siap pakai

- MUSE: “Audit mesin sumber secara baca-saja; inventaris service, data, database, cron, tunnel, port, runtime, dan rollback.”

- CUE: “Audit kapasitas, sudo, SSH, systemd, rsync, ruang disk, port bentrok, dan jalur pemulihan.”

- Keduanya: “Pasang/aktifkan Tailscale; berikan tautan persetujuan bila perlu; laporkan nama dan IP Tailscale.”

- Anda: Setujui kedua node pada akun/tailnet yang sama.

- Keduanya: Uji Tailscale ping dua arah.

- MUSE: Buat kunci SSH migrasi; tampilkan public key saja.

- CUE: Pasang public key pada user tujuan.

- MUSE: Uji SSH melalui IP Tailscale.

- MUSE: Buat manifest migrasi tanpa menampilkan rahasia.

- CUE: Siapkan runtime, direktori, ownership, dan systemd; jangan nyalakan konsumen tunggal.

- MUSE: Dry-run dan salinan awal; database memakai snapshot/dump konsisten.

- CUE: Verifikasi salinan tanpa menyalakan produksi.

- MUSE: Hentikan sumber, buat backup final, final sync; laporkan CUTOVER_SUMBER_SIAP.

- CUE: Mulai service inti, tunnel, lalu konsumen tunggal; laporkan CUE_AKTIF_SEMENTARA.

- MUSE: Tetap pasif; jangan hapus data.

- CUE: Uji endpoint, data, log, akses publik, reboot, dan autostart; laporkan CUE_SIAP_PAKAI.

- MUSE: Nonaktifkan autostart lama; pertahankan backup dan rollback.
Migrasi selesai jika
CUE tetap sehat setelah reboot, semua akses bekerja, tidak ada konflik polling, dan MUSE tetap pasif tetapi masih dapat dipakai untuk rollback.
Cara memakai untuk mesin lain
Ganti hanya nama MUSE/CUE, hostname, IP Tailscale, user Linux, daftar service, direktori, port, dan metode backup database. Urutan kerja tidak berubah.
Panduan praktis migrasi dua bot · Versi 2.011
