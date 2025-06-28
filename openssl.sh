#!/bin/bash

# Script untuk membangun OpenSSL untuk Android di Google Colab (terinspirasi robertying/openssl-curl-android dan Termux)
# Target: android-arm64 (dapat diubah ke android-arm)
# Sistem: Ubuntu (Google Colab)

# Variabel konfigurasi
NDK_VERSION="r26d"
OPENSSL_VERSION="3.0.14"
API_LEVEL=21
TARGET="android-arm64"  # Ganti ke "android-arm" untuk ARM 32-bit
INSTALL_DIR="$HOME/openssl-android"
NDK_DIR="$HOME/android-ndk-$NDK_VERSION"
HOST_TAG="linux-x86_64"

# Fungsi untuk menangani error
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# 1. Instal dependensi sistem
echo "Menginstal dependensi sistem..."
sudo apt update -qq
sudo apt install -y -qq wget unzip perl make curl || error_exit "Gagal menginstal dependensi"

# 2. Unduh Android NDK
echo "Mengunduh Android NDK versi $NDK_VERSION..."
if [ ! -d "$NDK_DIR" ]; then
    wget -q https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip -O ndk.zip || error_exit "Gagal mengunduh NDK"
    unzip -q ndk.zip -d $HOME || error_exit "Gagal mengekstrak NDK"
    rm ndk.zip
else
    echo "NDK sudah ada di $NDK_DIR"
fi

# 3. Atur variabel lingkungan untuk Clang
echo "Mengatur variabel lingkungan untuk Clang..."
export ANDROID_NDK_HOME=$NDK_DIR
export ANDROID_NDK_ROOT=$NDK_DIR
export TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG
export PATH=$TOOLCHAIN/bin:$PATH
export TARGET_HOST=aarch64-linux-android
export ANDROID_ARCH=arm64-v8a
export CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
export CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
export AR=$TOOLCHAIN/bin/llvm-ar
export AS=$CC
export LD=$TOOLCHAIN/bin/ld.lld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
export CFLAGS="-fPIC -D__ANDROID_API__=$API_LEVEL -I$TOOLCHAIN/sysroot/usr/include -I$TOOLCHAIN/sysroot/usr/include/aarch64-linux-android -pthread"
export LDFLAGS="-L$TOOLCHAIN/sysroot/usr/lib/aarch64-linux-android/$API_LEVEL -lc -pthread"

# Untuk android-arm (ARM 32-bit), uncomment baris berikut dan comment baris di atas
# export TARGET_HOST=armv7a-linux-androideabi
# export ANDROID_ARCH=armeabi-v7a
# export CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
# export CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
# export AR=$TOOLCHAIN/bin/llvm-ar
# export AS=$CC
# export LD=$TOOLCHAIN/bin/ld.lld
# export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
# export STRIP=$TOOLCHAIN/bin/llvm-strip
# export CFLAGS="-fPIC -D__ANDROID_API__=$API_LEVEL -I$TOOLCHAIN/sysroot/usr/include -I$TOOLCHAIN/sysroot/usr/include/arm-linux-androideabi -pthread"
# export LDFLAGS="-L$TOOLCHAIN/sysroot/usr/lib/arm-linux-androideabi/$API_LEVEL -lc -pthread"

# Verifikasi toolchain
command -v $CC >/dev/null 2>&1 || error_exit "Clang tidak ditemukan di $TOOLCHAIN"
command -v $LD >/dev/null 2>&1 || error_exit "LLD linker tidak ditemukan"

# 4. Unduh OpenSSL
echo "Mengunduh OpenSSL versi $OPENSSL_VERSION..."
if [ ! -d "openssl-$OPENSSL_VERSION" ]; then
    wget -q https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz || error_exit "Gagal mengunduh OpenSSL"
    tar -xzf openssl-$OPENSSL_VERSION.tar.gz || error_exit "Gagal mengekstrak OpenSSL"
    rm openssl-$OPENSSL_VERSION.tar.gz
else
    echo "OpenSSL sudah ada di openssl-$OPENSSL_VERSION"
fi

cd openssl-$OPENSSL_VERSION || error_exit "Gagal masuk ke direktori OpenSSL"

# 5. Konfigurasi OpenSSL
echo "Mengkonfigurasi OpenSSL untuk $TARGET..."
./Configure $TARGET \
    -D__ANDROID_API__=$API_LEVEL \
    --prefix=$INSTALL_DIR/$ANDROID_ARCH \
    --openssldir=$INSTALL_DIR/$ANDROID_ARCH/etc/tls \
    no-shared \
    no-legacy \
    no-module \
    --with-rand-seed=os || error_exit "Gagal mengkonfigurasi OpenSSL. Periksa config.log"

# 6. Periksa dan bersihkan Makefile
echo "Membersihkan Makefile dari flag yang salah..."
sed -i 's/-gcc-toolchain[^ ]*//g' Makefile
sed -i 's/-target[^ ]*//g' Makefile
grep -r "gcc-toolchain" Makefile && error_exit "Flag -gcc-toolchain masih ada di Makefile"
grep -r "target.*toolchains" Makefile && error_exit "Flag -target salah masih ada di Makefile"

# 7. Kompilasi dan instal
echo "Mengkompilasi OpenSSL..."
make -j$(nproc) V=1 || error_exit "Gagal mengkompilasi OpenSSL. Periksa output atau config.log"
echo "Menginstal OpenSSL ke $INSTALL_DIR/$ANDROID_ARCH..."
make install_sw || error_exit "Gagal menginstal OpenSSL"

# 8. Verifikasi instalasi
echo "Memverifikasi instalasi..."
if [ -f "$INSTALL_DIR/$ANDROID_ARCH/lib/libcrypto.a" ] && [ -f "$INSTALL_DIR/$ANDROID_ARCH/lib/libssl.a" ]; then
    echo "OpenSSL berhasil di-build dan diinstal di $INSTALL_DIR/$ANDROID_ARCH"
    echo "Include path: $INSTALL_DIR/$ANDROID_ARCH/include"
    echo "Library path: $INSTALL_DIR/$ANDROID_ARCH/lib"
else
    error_exit "File library OpenSSL tidak ditemukan"
fi

# 9. Bersihkan
echo "Membersihkan file sementara..."
make clean
cd ..

echo "Proses selesai! Gunakan library di $INSTALL_DIR/$ANDROID_ARCH untuk proyek Anda."
