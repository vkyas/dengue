#!/bin/bash

# ====== Variabel Konfigurasi ======
NDK_VERSION="r26d"
OPENSSL_VERSION="3.5.0"
CURL_VERSION="8.7.1"
API_LEVEL=21
TARGET="android-arm"
ANDROID_ARCH="armeabi-v7a"
TARGET_HOST="armv7a-linux-androideabi"
INSTALL_DIR_OPENSSL="$HOME/openssl-android"
INSTALL_DIR_CURL="$HOME/curl-android"
NDK_DIR="$HOME/android-ndk-$NDK_VERSION"
HOST_TAG="linux-x86_64"

# ====== Fungsi Error Handler ======
error_exit() {
    echo "❌ Error: $1" >&2
    exit 1
}

# ====== Unduh Android NDK ======
echo "📦 Mengunduh Android NDK versi $NDK_VERSION..."
if [ ! -d "$NDK_DIR" ]; then
    wget -q https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip -O ndk.zip || error_exit "Gagal mengunduh NDK"
    unzip -q ndk.zip -d $HOME || error_exit "Gagal mengekstrak NDK"
    rm ndk.zip
else
    echo "✅ NDK sudah tersedia di $NDK_DIR"
fi

# ====== Atur Toolchain ======
echo "⚙️  Menyiapkan environment toolchain..."
export ANDROID_NDK_ROOT="$NDK_DIR"
export TOOLCHAIN=$NDK_DIR/toolchains/llvm/prebuilt/$HOST_TAG
export PATH=$TOOLCHAIN/bin:$PATH
export CC=$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang
export CXX=$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang++
export AR=$TOOLCHAIN/bin/llvm-ar
export AS=$CC
export LD=$TOOLCHAIN/bin/ld.lld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
export CFLAGS="-fPIC -Os -D__ANDROID_API__=$API_LEVEL -static"
export CPPFLAGS="-D__ANDROID_API__=$API_LEVEL"
export LDFLAGS="-static -Wl,--strip-all -Wl,--exclude-libs,ALL -Wl,--gc-sections"

# ====== Build OpenSSL ======
echo "⬇️  Mengunduh OpenSSL $OPENSSL_VERSION..."
if [ ! -d "openssl-$OPENSSL_VERSION" ]; then
    curl -sLO https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz || error_exit "Gagal mengunduh OpenSSL"
    tar xf openssl-$OPENSSL_VERSION.tar.gz || error_exit "Gagal mengekstrak OpenSSL"
fi

cd openssl-$OPENSSL_VERSION || error_exit "Tidak dapat masuk ke direktori OpenSSL"

echo "🔧 Mengkonfigurasi OpenSSL..."
./Configure android-arm \
    --prefix=$INSTALL_DIR_OPENSSL/$ANDROID_ARCH \
    --cross-compile-prefix=$TOOLCHAIN/bin/${TARGET_HOST}- \
    no-shared no-legacy no-tests no-apps || error_exit "Konfigurasi OpenSSL gagal"

# ✅ Hanya lanjut jika Makefile terbentuk
if [ -f Makefile ]; then
    echo "🧹 Membersihkan flag -gcc-toolchain dan -target dari Makefile..."
    sed -i 's/-gcc-toolchain[^ ]*//g' Makefile
    sed -i 's/-target[^ ]*//g' Makefile
else
    error_exit "Makefile tidak ditemukan! Konfigurasi gagal?"
fi

echo "🏗️  Membuild OpenSSL..."
make -j$(nproc) build_libs || error_exit "Build library OpenSSL gagal"
make install_sw || error_exit "Instalasi OpenSSL gagal"
cd ..

# ====== Build cURL ======
echo "⬇️  Mengunduh cURL $CURL_VERSION..."
if [ ! -d "curl-$CURL_VERSION" ]; then
    curl -sLO https://curl.se/download/curl-$CURL_VERSION.tar.gz || error_exit "Gagal mengunduh cURL"
    tar xf curl-$CURL_VERSION.tar.gz || error_exit "Gagal mengekstrak cURL"
fi

cd curl-$CURL_VERSION || error_exit "Tidak dapat masuk ke direktori cURL"

echo "🔧 Konfigurasi cURL statis..."
./configure --host=$TARGET_HOST \
    --prefix=$INSTALL_DIR_CURL/$ANDROID_ARCH \
    --with-openssl=$INSTALL_DIR_OPENSSL/$ANDROID_ARCH \
    --disable-shared \
    --enable-static \
    --disable-ldap \
    --disable-ldaps \
    --disable-manual \
    --without-zlib \
    --without-libidn2 \
    --without-nghttp2 \
    --without-brotli \
    --without-zstd \
    --disable-verbose \
    --disable-debug \
    --disable-curldebug \
    --enable-optimize \
    LIBS="-ldl -lm" || error_exit "Konfigurasi cURL gagal"

echo "🏗️  Membuild cURL..."
make -j$(nproc) || error_exit "Build cURL gagal"
make install || error_exit "Instalasi cURL gagal"

# ====== Optimasi dan Verifikasi ======
echo "🧽 Men-strip binary..."
$STRIP $INSTALL_DIR_CURL/$ANDROID_ARCH/bin/curl

echo "✅ Binary cURL statis siap:"
ls -lh $INSTALL_DIR_CURL/$ANDROID_ARCH/bin/curl
$INSTALL_DIR_CURL/$ANDROID_ARCH/bin/curl --version

