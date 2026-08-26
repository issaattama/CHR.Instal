# CHRVPS
This is a script to automatically install Mikrotik Chr on Ubuntu versions 20.04, 22.04, and 24.04.

# Usage
```
sudo su
```
```
git clone https://github.com/issaattama/CHRVPS
```
```
cd CHRVPS
```
```
chmod +x install.sh
```
```
sudo apt-get install dos2unix
```
```
dos2unix install.sh
```
```
bash install.sh
```

# 1. Masuk sebagai hak akses tertinggi (root)
sudo su

# 2. Unduh folder installer dari GitHub
git clone https://github.com/issaattama/CHRVPS

# 3. Masuk ke dalam folder yang sudah diunduh
cd CHRVPS

# 4. Hapus karakter eror Windows (\r) menggunakan perintah sed
sed -i 's/\r$//' install.sh

# 5. Berikan izin eksekusi pada file install.sh
chmod +x install.sh

# 6. Jalankan installer MikroTik CHR
bash install.sh


# Full Tutorial
https://youtu.be/1_2Cz3szT0Q
  
