# Auto Installer MikroTik CHR v6 & v7 untuk VPS Linux

Script otomatis untuk mengubah OS VPS Ubuntu (**20.04, 22.04, dan 24.04**) menjadi MikroTik RouterOS (CHR) versi 6 atau versi 7. Script ini secara cerdas mendeteksi IP, Gateway, Interface, dan menyesuaikan tabel partisi otomatis (*Offset Multi-version*).

> **PERINGATAN:** Proses ini akan menghapus seluruh data dan sistem operasi Ubuntu lama Anda. Gunakan hanya pada VPS kosong/baru!

## Fitur Utama
- Mendukung Ubuntu 20.04, 22.04, dan 24.04 LTS.
- Mendukung instalasi **MikroTik v6** (Automated Offset 512).
- Mendukung instalasi **MikroTik v7** (Automated Offset 33554432).
- Bebas eror format Windows (`\r\n`) saat ditarik menggunakan git.
- Deteksi IP Statis, Gateway, Interface, dan Disk otomatis.
- Validasi format versi RouterOS sebelum diunduh.
- Konfirmasi manual (ketik `YAKIN`) sebelum disk dihapus — menampilkan disk, interface, IP, dan gateway yang terdeteksi.
- Pengecekan setiap tahap kritis (download, mount, flashing) — proses berhenti dengan pesan jelas jika ada yang gagal, bukan lanjut diam-diam.

---

## Cara Instalasi

### Langkah 1: Masuk ke VPS via SSH
Login ke terminal VPS Anda sebagai user root:
```bash
sudo su
```

### Langkah 2: Clone Repositori dan Jalankan Script
Salin urutan perintah berikut, tempelkan ke terminal, lalu tekan **Enter**:
```bash
git clone https://github.com/issaattama/CHR.Instal && cd CHR.Instal && sed -i 's/\r$//' install.sh && chmod +x install.sh && ./install.sh
```
Pilih versi (v6/v7) dan ikuti petunjuk. Cek versi resmi di MikroTik CHR Downloads [https://mikrotik.com](https://mikrotik.com/download/chr).

### Langkah 3: Ikuti Instruksi di Layar
1. Pilih angka `1` untuk RouterOS v7 atau `2` untuk RouterOS v6.
2. Ketik versi spesifik yang ingin diunduh (Contoh: `7.21.5` atau `6.49.17`).
3. Script akan menampilkan disk, interface, IP, dan gateway yang berhasil dideteksi — **periksa dulu apakah sudah sesuai** sebelum melanjutkan.
4. Ketik `YAKIN` (huruf besar) untuk mengonfirmasi bahwa Anda sadar seluruh isi disk akan terhapus.
5. Tunggu proses instalasi hingga VPS melakukan *reboot* otomatis dan memutuskan koneksi SSH.

> Jika salah satu tahap gagal (misalnya versi tidak ditemukan, mount offset tidak cocok, atau proses `dd` terhenti), script akan berhenti dan menampilkan pesan error — VPS **tidak** akan direboot otomatis dalam kondisi tersebut, supaya Anda sempat menghubungi provider untuk akses rescue/console bila perlu.

---

## Cara Mengakses MikroTik Setelah Install
1. Tunggu sekitar **1–2 menit** pasca *reboot*.
2. Buka aplikasi **Winbox** di komputer Anda.
3. Masukkan **IP Publik VPS** Anda pada kolom *Connect To*.
4. Isi kolom *Login*: `admin` dan biarkan *Password* **kosong**.
5. Klik **Connect** dan Anda akan langsung diminta membuat password baru.

## Troubleshooting
- **Mount gagal / offset tidak cocok**: kemungkinan versi RouterOS yang dipilih memakai layout partisi berbeda dari yang diasumsikan script. Cek manual dengan `fdisk -lu chr-<versi>.img` setelah file image berhasil diunduh.
- **Deteksi disk/IP/gateway gagal**: script akan berhenti sebelum mengunduh apa pun. Periksa manual dengan `lsblk`, `ip route`, dan `ip addr` lalu sesuaikan variabel di script bila perlu.
- **`dd` gagal di tengah proses**: jangan reboot manual. Disk kemungkinan dalam kondisi tidak konsisten — hubungi provider VPS untuk akses rescue/console.
