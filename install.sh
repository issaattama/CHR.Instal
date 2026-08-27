#!/usr/bin/env bash
set -u

# Fungsi animasi loading
show_loading() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    echo " "
}

# Cek akses root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\e[31mError: Script ini harus dijalankan sebagai ROOT (sudo su).\e[0m"
        exit 1
    fi
}

# Tampilkan spesifikasi VPS
show_system_details() {
    echo -e "\e[34m[1/5] Memeriksa spesifikasi VPS...\e[0m"
    IP=$(curl -s http://checkip.amazonaws.com)
    RAM=$(free -m | awk '/Mem:/ { print $2 }')
    CPU=$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)
    STORAGE=$(df -h | awk '$NF=="/"{printf "%s", $2}')
    echo -e "\e[32mDetail Sistem:\n- IP Publik : $IP\n- RAM       : ${RAM}MB\n- CPU       : $CPU\n- Storage   : $STORAGE\e[0m\n"
}

# Banner ASCII
echo -e "\e[36m===============================================\e[0m"
echo -e "\e[33m    MIKROTIK CHR AUTOMATIC INSTALLER v6 & v7   \e[0m"
echo -e "\e[36m===============================================\e[0m"

check_root
show_system_details

# Meminta input versi dari pengguna
echo -e "\e[34mPilih Versi MikroTik RouterOS yang ingin di-install:\e[0m"
echo "1) MikroTik v7 (Rekomendasi: 7.21.5 atau v7 LongTerm terbaru)"
echo "2) MikroTik v6 (Rekomendasi: 6.49.20 atau v6 LongTerm terbaru)"
read -p "Masukkan pilihan Anda (1 atau 2): " VERSION_CHOICE

if [ "$VERSION_CHOICE" == "1" ]; then
    read -p "Masukkan nomor versi v7 yang diinginkan (Contoh: 7.21.5): " CHR_VERSION
    OFFSET=33554432
elif [ "$VERSION_CHOICE" == "2" ]; then
    read -p "Masukkan nomor versi v6 yang diinginkan (Contoh: 6.49.20): " CHR_VERSION
    OFFSET=512
else
    echo -e "\e[31mPilihan tidak valid. Proses dibatalkan.\e[0m"
    exit 1
fi

# Validasi format versi (angka & titik saja) supaya tidak nyasar ke URL aneh
if ! [[ "$CHR_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo -e "\e[31mFormat versi tidak valid. Contoh yang benar: 7.21.5\e[0m"
    exit 1
fi

# Deteksi disk & interface lebih dulu, supaya user bisa konfirmasi sebelum apa pun diunduh
DISK=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1; exit}')
INTERFACE=$(ip -o -4 route show to default | awk '{print $5; exit}')
INTERFACE_IP=$(ip -4 -o addr show "$INTERFACE" 2>/dev/null | awk '{print $4; exit}')
INTERFACE_GATEWAY=$(ip route show | awk '/default/{print $3; exit}')

if [ -z "$DISK" ] || [ -z "$INTERFACE" ] || [ -z "$INTERFACE_IP" ] || [ -z "$INTERFACE_GATEWAY" ]; then
    echo -e "\e[31mGagal mendeteksi disk/interface/IP/gateway secara otomatis.\e[0m"
    echo "DISK=$DISK  INTERFACE=$INTERFACE  IP=$INTERFACE_IP  GATEWAY=$INTERFACE_GATEWAY"
    echo "Periksa manual sebelum lanjut (script dihentikan demi keamanan)."
    exit 1
fi

echo -e "\e[33m--- Konfirmasi sebelum menghapus seluruh isi VPS ---\e[0m"
echo "Disk target   : /dev/$DISK (SELURUH ISI AKAN DIHAPUS)"
echo "Interface     : $INTERFACE"
echo "IP yang akan dipasang ke RouterOS : $INTERFACE_IP"
echo "Gateway       : $INTERFACE_GATEWAY"
echo "RouterOS      : v$CHR_VERSION (offset $OFFSET)"
read -p "Ketik YAKIN (huruf besar) untuk melanjutkan: " CONFIRM
if [ "$CONFIRM" != "YAKIN" ]; then
    echo "Dibatalkan oleh user."
    exit 1
fi

echo -e "\n\e[34m[2/5] Menyiapkan package dependencies (wget & unzip)...\e[0m"
{
    apt-get update -y > /dev/null 2>&1
    apt-get install wget unzip -y > /dev/null 2>&1
} & show_loading

if ! command -v wget >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo -e "\e[31mGagal memasang wget/unzip. Cek koneksi/apt repo VPS Anda.\e[0m"
    exit 1
fi

echo -e "\e[34m[3/5] Mengunduh MikroTik CHR v$CHR_VERSION...\e[0m"
{
    wget -qO routeros.zip "https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip" && \
    unzip -o routeros.zip > /dev/null 2>&1 && \
    rm -f routeros.zip
} & show_loading

if [ ! -f "chr-$CHR_VERSION.img" ]; then
    echo -e "\e[31mGagal mengunduh/mengekstrak file! Pastikan nomor versi benar dan tersedia di download.mikrotik.com.\e[0m"
    exit 1
fi

echo -e "\e[34m[4/5] Memasang IP otomatis ke dalam Image (Offset: $OFFSET)...\e[0m"
mkdir -p /mnt/mikrotik
if ! mount -o loop,offset=$OFFSET "chr-$CHR_VERSION.img" /mnt/mikrotik; then
    echo -e "\e[31mMount gagal pada offset $OFFSET. Kemungkinan layout partisi versi ini berbeda dari yang diasumsikan script.\e[0m"
    echo "Cek manual dengan: fdisk -lu chr-$CHR_VERSION.img"
    exit 1
fi

mkdir -p /mnt/mikrotik/rw
echo "/ip address add address=${INTERFACE_IP} interface=[/interface ethernet find where name=ether1]" > /mnt/mikrotik/rw/autorun.scr
echo "/ip route add gateway=${INTERFACE_GATEWAY}" >> /mnt/mikrotik/rw/autorun.scr

sync
if ! umount /mnt/mikrotik; then
    echo -e "\e[31mGagal unmount /mnt/mikrotik. Menghentikan proses demi keamanan (autorun.scr mungkin belum ter-flush).\e[0m"
    exit 1
fi

echo -e "\e[34m[5/5] Melakukan Flashing ke Harddisk (/dev/$DISK) & Reboot...\e[0m"
sleep 2
echo u > /proc/sysrq-trigger
sync

if dd if="chr-$CHR_VERSION.img" of="/dev/${DISK}" bs=4M oflag=sync status=none; then
    echo -e "\e[32mFlashing berhasil. VPS akan otomatis restart dalam 5 detik.\e[0m"
    echo -e "\e[33mSilakan login menggunakan Winbox setelah VPS menyala kembali (IP: ${INTERFACE_IP%/*}).\e[0m"
    sleep 5
    echo b > /proc/sysrq-trigger
else
    echo -e "\e[31mdd GAGAL di tengah proses! Disk kemungkinan dalam kondisi tidak konsisten.\e[0m"
    echo -e "\e[31mJANGAN reboot manual — hubungi provider VPS untuk akses rescue/console sebelum bertindak lebih lanjut.\e[0m"
    exit 1
fi
