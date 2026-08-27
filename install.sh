#!/usr/bin/env bash

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
    IP=$(curl -s http://amazonaws.com)
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
echo "1) MikroTik v7 (Rekomendasi: 7.21.5 atau v7 terbaru)"
echo "2) MikroTik v6 (Rekomendasi: 6.49.20 atau v6 lama)"
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

echo -e "\n\e[34m[2/5] Menyiapkan package dependencies (wget & unzip)...\e[0m"
{
    apt-get update -y > /dev/null 2>&1
    apt-get install wget unzip -y > /dev/null 2>&1
} & show_loading

# Membaca konfigurasi jaringan VPS asli
DISK=$(lsblk | grep "disk" | head -n 1 | cut -d' ' -f1)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
INTERFACE_IP=$(ip addr show $INTERFACE | grep global | cut -d' ' -f 6 | head -n 1)
INTERFACE_GATEWAY=$(ip route show | grep default | awk '{print $3}')

echo -e "\e[34m[3/5] Mengunduh MikroTik CHR v$CHR_VERSION...\e[0m"
{
    wget -qO routeros.zip https://mikrotik.com && \
    unzip routeros.zip > /dev/null 2>&1 && \
    rm -rf routeros.zip
} & show_loading

if [ ! -f "chr-$CHR_VERSION.img" ]; then
    echo -e "\e[31mGagal mengunduh file! Pastikan nomor versi benar.\e[0m"
    exit 1
fi

echo -e "\e[34m[4/5] Memasang IP otomatis ke dalam Image (Offset: $OFFSET)...\e[0m"
{
    mkdir -p /mnt/mikrotik
    mount -o loop,offset=$OFFSET chr-$CHR_VERSION.img /mnt/mikrotik > /dev/null 2>&1
    mkdir -p /mnt/mikrotik/rw
    
    # Membuat script autorun IP jaringan
    echo "/ip address add address=${INTERFACE_IP} interface=[/interface ethernet find where name=ether1]" > /mnt/mikrotik/rw/autorun.scr
    echo "/ip route add gateway=${INTERFACE_GATEWAY}" >> /mnt/mikrotik/rw/autorun.scr
    
    umount /mnt/mikrotik > /dev/null 2>&1
} & show_loading

echo -e "\e[34m[5/5] Melakukan Flashing ke Harddisk (/dev/$DISK) & Reboot...\e[0m"
sleep 2
{
    echo u > /proc/sysrq-trigger
    dd if=chr-$CHR_VERSION.img of=/dev/${DISK} bs=4M oflag=sync > /dev/null 2>&1
} & show_loading

echo -e "\e[32mInstalasi Selesai! VPS akan otomatis restart dalam 5 detik.\e[0m"
echo -e "\e[33mSilakan login menggunakan Winbox setelah VPS menyala kembali.\e[0m"
sleep 5
echo b > /proc/sysrq-trigger
