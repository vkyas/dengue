# #!/bin/bash

# # =================================================================
# # KONFIGURASI TARGET: PHP 8.4.8 dengan modul mirip PHP 7.3
# # =================================================================
# export NDK_VERSION="r26d"
# export PHP_VERSION="8.4.8"
# export API_LEVEL="22"
# export HOST_TRIPLE="armv7a-linux-androideabi"

# # =================================================================
# # DIREKTORI & LOG
# # =================================================================
# export BASE_DIR="$(pwd)"
# export WORKDIR="$BASE_DIR/build-arm32"
# export OUTDIR="$BASE_DIR/output-arm32"
# export PREFIX="$WORKDIR/sysroot-arm32"
# export LOG_FILE="$BASE_DIR/build.log"

# step() { echo -e "\n\e[1;34mSTEP: $1\e[0m"; }

# # ---- PERBAIKAN: Pembersihan Paksa ----
# step "Membersihkan lingkungan build sebelumnya"
# rm -f "$LOG_FILE"
# rm -rf "$WORKDIR" "$OUTDIR"

# exec &> >(tee -a "$LOG_FILE")

# mkdir -p "$WORKDIR" "$OUTDIR" "$PREFIX"
# cd "$WORKDIR"

# # =================================================================
# # PERSIAPAN TOOLCHAIN NDK
# # =================================================================
# step "Mengunduh Android NDK"
# NDK_DIR="android-ndk-$NDK_VERSION"
# NDK_ZIP="$NDK_DIR-linux.zip"
# [ ! -d "$NDK_DIR" ] && { [ ! -f "$NDK_ZIP" ] && wget -q https://dl.google.com/android/repository/$NDK_ZIP; unzip -q "$NDK_ZIP"; }
# export NDK_HOME="$WORKDIR/$NDK_DIR"

# step "Menyiapkan Toolchain"
# export TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
# export PATH="$TOOLCHAIN/bin:$PATH"
# export CC="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang"
# export CXX="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang++"
# export AR="$TOOLCHAIN/bin/llvm-ar"
# export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
# export STRIP="$TOOLCHAIN/bin/llvm-strip"
# export SYSROOT="$TOOLCHAIN/sysroot"
# export CFLAGS="--sysroot=$SYSROOT -fPIC -Os -I$PREFIX/include"
# export LDFLAGS="--sysroot=$SYSROOT -L$PREFIX/lib"
# export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# # =================================================================
# # BUILD DEPENDENSI PUSTAKA STATIS
# # =================================================================

# # Build zlib
# step "Build zlib (statis)"
# if [ ! -f "$PREFIX/lib/libz.a" ]; then
#   ZLIB_VERSION="1.3.1"; ZLIB_FILE="zlib-${ZLIB_VERSION}.tar.gz"; [ ! -f "$ZLIB_FILE" ] && wget -q https://zlib.net/${ZLIB_FILE}; tar -xzf "$ZLIB_FILE" && cd "zlib-${ZLIB_VERSION}"; ./configure --prefix="$PREFIX" --static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# # Build OpenSSL (statis)
# step "Build OpenSSL (statis)"
# if [ ! -f "$PREFIX/lib/libssl.a" ]; then
#   OPENSSL_VERSION="3.5.0"
#   OPENSSL_FILE="openssl-${OPENSSL_VERSION}.tar.gz"
#   [ ! -f "$OPENSSL_FILE" ] && wget -q https://www.openssl.org/source/${OPENSSL_FILE}
#   tar -xzf "$OPENSSL_FILE" && cd "openssl-${OPENSSL_VERSION}"
#   ./Configure linux-generic32 \
#     --prefix="$PREFIX" \
#     -D__ANDROID_API__=$API_LEVEL \
#     no-shared no-tests no-asm
#   make -j$(nproc) && make install_sw

#   cd "$WORKDIR"
# fi

# # Build libiconv
# step "Build libiconv (statis)"
# if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
#   ICONV_FILE="libiconv-1.17.tar.gz"; [ ! -f "$ICONV_FILE" ] && wget -q https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz; tar -xzf "$ICONV_FILE" && cd libiconv-1.17; ac_cv_func_mempcpy=no ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# # Build libxml2
# step "Build libxml2 (statis)"
# if [ ! -f "$PREFIX/lib/libxml2.a" ]; then
#   LIBXML2_VERSION="2.12.7"; LIBXML2_FILE="libxml2-${LIBXML2_VERSION}.tar.xz"; [ ! -f "$LIBXML2_FILE" ] && wget -q https://download.gnome.org/sources/libxml2/2.12/${LIBXML2_FILE}; tar -xf "$LIBXML2_FILE" && cd "libxml2-${LIBXML2_VERSION}"; ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --without-python --with-zlib="$PREFIX" --without-lzma; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# # Build Oniguruma
# step "Build Oniguruma (statis)"
# if [ ! -f "$PREFIX/lib/libonig.a" ]; then
#   ONIG_VERSION="6.9.9"; ONIG_FILE="onig-${ONIG_VERSION}.tar.gz"; [ ! -f "$ONIG_FILE" ] && wget -q "https://github.com/kkos/oniguruma/releases/download/v${ONIG_VERSION}/onig-${ONIG_VERSION}.tar.gz"; tar -xzf "$ONIG_FILE" && cd "onig-${ONIG_VERSION}"; ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# # Build SQLite
# step "Build SQLite (statis)"
# if [ ! -f "$PREFIX/lib/libsqlite3.a" ]; then
#     SQLITE_VERSION="3460000"; SQLITE_YEAR="2024"; SQLITE_FILE="sqlite-amalgamation-${SQLITE_VERSION}.zip"; [ ! -f "$SQLITE_FILE" ] && wget -q https://www.sqlite.org/${SQLITE_YEAR}/${SQLITE_FILE}; unzip -q "$SQLITE_FILE" && cd "sqlite-amalgamation-${SQLITE_VERSION}"; $CC $CFLAGS -c sqlite3.c -o sqlite3.o; $AR rcs "$PREFIX/lib/libsqlite3.a" sqlite3.o; cp sqlite3.h "$PREFIX/include/"; cd "$WORKDIR"; fi

# # ---- PERBAIKAN: Build ICU4C dalam Dua Tahap ----
# step "Build ICU4C (statis)"
# if [ ! -f "$PREFIX/lib/libicuuc.a" ]; then
#     ICU_VERSION="75.1"
#     ICU_VERSION_US="75_1"
#     ICU_SRC_DIR="icu"
#     ICU_FILE="icu4c-${ICU_VERSION_US}-src.tgz"
#     ICU_HOST_BUILD_DIR="$WORKDIR/icu-host-build"
#     ICU_TARGET_BUILD_DIR="$WORKDIR/icu-target-build"

#     [ ! -f "$ICU_FILE" ] && wget -q https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/${ICU_FILE}
#     [ ! -d "$ICU_SRC_DIR" ] && tar -xzf "$ICU_FILE"

#     # Tahap 1: Build untuk Host (x86_64) untuk menghasilkan alat bantu
#     step "Build ICU4C - Tahap 1: Host Tools"
#     mkdir -p "$ICU_HOST_BUILD_DIR" && cd "$ICU_HOST_BUILD_DIR"
#     # PERBAIKAN: Reset variabel lingkungan agar menggunakan kompilator host (gcc)
#     CC="gcc" CXX="g++" CFLAGS="" LDFLAGS="" CPPFLAGS="" ../$ICU_SRC_DIR/source/configure --prefix="$ICU_HOST_BUILD_DIR/install" --disable-samples --disable-tests
#     CC="gcc" CXX="g++" make -j$(nproc)

#     cd "$WORKDIR"

#     # Tahap 2: Build untuk Target (ARM) menggunakan alat dari Tahap 1
#     step "Build ICU4C - Tahap 2: Target Library"
#     mkdir -p "$ICU_TARGET_BUILD_DIR" && cd "$ICU_TARGET_BUILD_DIR"
#     ../$ICU_SRC_DIR/source/configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
#         --with-cross-build="$ICU_HOST_BUILD_DIR" \
#         --disable-shared --enable-static \
#         --with-data-packaging=static \
#         --disable-samples --disable-tests
#     make -j$(nproc) && make install
    
#     cd "$WORKDIR"
# fi

# # Verifikasi Instalasi
# step "Verifikasi instalasi ICU"; if [ ! -f "$PREFIX/include/unicode/parseerr.h" ]; then echo -e "\n\e[1;31mKESALAHAN: Header ICU 'parseerr.h' tidak ditemukan.\e[0m"; exit 1; else echo -e "\e[1;32mHeader ICU ditemukan.\e[0m"; fi

# # Build libcurl
# step "Build libcurl (statis)"; if [ ! -f "$PREFIX/lib/libcurl.a" ]; then CURL_VERSION="8.7.1"; CURL_FILE="curl-${CURL_VERSION}.tar.xz"; [ ! -f "$CURL_FILE" ] && wget -q https://curl.se/download/${CURL_FILE}; tar -xf "$CURL_FILE" && cd "curl-${CURL_VERSION}"; ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --with-ssl="$PREFIX" --without-zstd --disable-ldap; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# # Build PHP
# step "Unduh dan konfigurasikan PHP"; PHP_SRC="php-$PHP_VERSION"; PHP_FILE="php-${PHP_VERSION}.tar.gz"; [ ! -d "$PHP_SRC" ] && { [ ! -f "$PHP_FILE" ] && wget -q https://github.com/vkyas/dengue/releases/download/php-8.4.8/php-${PHP_VERSION}.tar.gz; tar -xzf "$PHP_FILE"; }; cd "$PHP_SRC"; [ -f "Makefile" ] && make distclean; ./buildconf --force; ./configure --build=x86_64-pc-linux-gnu --host="$HOST_TRIPLE" --prefix="$OUTDIR" --disable-all --disable-phpdbg --enable-cli --enable-ctype --enable-dom --enable-filter --enable-json --enable-mysqlnd --enable-pdo --enable-session --enable-sockets --enable-sqlite3="$PREFIX" --enable-xml --with-curl="$PREFIX" --with-iconv="$PREFIX" --with-openssl="$PREFIX" --with-pcre --with-pdo-sqlite="$PREFIX" --with-zlib="$PREFIX" --with-libxml="$PREFIX" --enable-simplexml --enable-xmlreader --enable-xmlwriter --enable-mbstring --with-onig="$PREFIX" --enable-intl --with-icu-dir="$PREFIX" --enable-opcache;
# step "Build dan Install PHP"; make -j$(nproc); make install; cd "$WORKDIR";

# # Finalisasi
# step "Finalisasi dan strip"; $STRIP --strip-unneeded "$OUTDIR/bin/php";
# step "Membuat php.ini minimal"; INI_DIR="$OUTDIR/ini"; mkdir -p "$INI_DIR"; cat > "$INI_DIR/php.ini" <<EOF
# [PHP]
# memory_limit = 128M
# expose_php = On
# EOF
# step "Pengemasan"; TAR_FILE="$BASE_DIR/php-android-arm32-v${PHP_VERSION}.tar.gz"; tar -czvf "$TAR_FILE" -C "$OUTDIR" .;
# echo -e "\n\e[1;32m✅ Build selesai. File: $TAR_FILE\e[0m"










#!/bin/bash

# =================================================================
# KONFIGURASI TARGET: PHP 8.4.8 dengan modul mirip PHP 7.3
# =================================================================
export NDK_VERSION="r26d"
export PHP_VERSION="8.4.8"
export API_LEVEL="22"
export HOST_TRIPLE="armv7a-linux-androideabi"

# =================================================================
# DIREKTORI & LOG
# =================================================================
export BASE_DIR="$(pwd)"
export WORKDIR="$BASE_DIR/build-arm32"
export OUTDIR="$BASE_DIR/output-arm32"
export PREFIX="$WORKDIR/sysroot-arm32"
export LOG_FILE="$BASE_DIR/build.log"

step() { echo -e "\n\e[1;34mSTEP: $1\e[0m"; }

# ---- PERBAIKAN: Pembersihan Paksa ----
step "Membersihkan lingkungan build sebelumnya"
rm -f "$LOG_FILE"
rm -rf "$WORKDIR" "$OUTDIR"

exec &> >(tee -a "$LOG_FILE")

mkdir -p "$WORKDIR" "$OUTDIR" "$PREFIX"
cd "$WORKDIR"

# =================================================================
# PERSIAPAN TOOLCHAIN NDK
# =================================================================
step "Mengunduh Android NDK"
NDK_DIR="android-ndk-$NDK_VERSION"
NDK_ZIP="$NDK_DIR-linux.zip"
[ ! -d "$NDK_DIR" ] && { [ ! -f "$NDK_ZIP" ] && wget -q https://dl.google.com/android/repository/$NDK_ZIP; unzip -q "$NDK_ZIP"; }
export NDK_HOME="$WORKDIR/$NDK_DIR"

step "Menyiapkan Toolchain"
export TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
export PATH="$TOOLCHAIN/bin:$PATH"
export CC="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export SYSROOT="$TOOLCHAIN/sysroot"
export CFLAGS="--sysroot=$SYSROOT -fPIC -Os -I$PREFIX/include"
export LDFLAGS="--sysroot=$SYSROOT -L$PREFIX/lib"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# =================================================================
# BUILD DEPENDENSI PUSTAKA STATIS
# =================================================================

# Build zlib
step "Build zlib (statis)"
if [ ! -f "$PREFIX/lib/libz.a" ]; then
  ZLIB_VERSION="1.3.1"; ZLIB_FILE="zlib-${ZLIB_VERSION}.tar.gz"; [ ! -f "$ZLIB_FILE" ] && wget -q https://zlib.net/${ZLIB_FILE}; tar -xzf "$ZLIB_FILE" && cd "zlib-${ZLIB_VERSION}"; ./configure --prefix="$PREFIX" --static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# Build OpenSSL (statis)
step "Build OpenSSL (statis)"
if [ ! -f "$PREFIX/lib/libssl.a" ]; then
  OPENSSL_VERSION="3.5.0"
  OPENSSL_FILE="openssl-${OPENSSL_VERSION}.tar.gz"
  [ ! -f "$OPENSSL_FILE" ] && wget -q https://www.openssl.org/source/${OPENSSL_FILE}
  tar -xzf "$OPENSSL_FILE" && cd "openssl-${OPENSSL_VERSION}"
  ./Configure linux-generic32 \
    --prefix="$PREFIX" \
    -D__ANDROID_API__=$API_LEVEL \
    no-shared no-tests no-asm
  make -j$(nproc) && make install_sw

  cd "$WORKDIR"
fi

# Build libiconv
step "Build libiconv (statis)"
if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
  ICONV_FILE="libiconv-1.17.tar.gz"; [ ! -f "$ICONV_FILE" ] && wget -q https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz; tar -xzf "$ICONV_FILE" && cd libiconv-1.17; ac_cv_func_mempcpy=no ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# Build libxml2
step "Build libxml2 (statis)"
if [ ! -f "$PREFIX/lib/libxml2.a" ]; then
  LIBXML2_VERSION="2.12.7"; LIBXML2_FILE="libxml2-${LIBXML2_VERSION}.tar.xz"; [ ! -f "$LIBXML2_FILE" ] && wget -q https://download.gnome.org/sources/libxml2/2.12/${LIBXML2_FILE}; tar -xf "$LIBXML2_FILE" && cd "libxml2-${LIBXML2_VERSION}"; ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --without-python --with-zlib="$PREFIX" --without-lzma; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# Build Oniguruma
step "Build Oniguruma (statis)"
if [ ! -f "$PREFIX/lib/libonig.a" ]; then
  ONIG_VERSION="6.9.9"; ONIG_FILE="onig-${ONIG_VERSION}.tar.gz"; [ ! -f "$ONIG_FILE" ] && wget -q "https://github.com/kkos/oniguruma/releases/download/v${ONIG_VERSION}/onig-${ONIG_VERSION}.tar.gz"; tar -xzf "$ONIG_FILE" && cd "onig-${ONIG_VERSION}"; ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static; make -j$(nproc) && make install; cd "$WORKDIR"; fi

# Build SQLite
step "Build SQLite (statis)"
if [ ! -f "$PREFIX/lib/libsqlite3.a" ]; then
    SQLITE_VERSION="3460000"; SQLITE_YEAR="2024"; SQLITE_FILE="sqlite-amalgamation-${SQLITE_VERSION}.zip"; [ ! -f "$SQLITE_FILE" ] && wget -q https://www.sqlite.org/${SQLITE_YEAR}/${SQLITE_FILE}; unzip -q "$SQLITE_FILE" && cd "sqlite-amalgamation-${SQLITE_VERSION}"; $CC $CFLAGS -c sqlite3.c -o sqlite3.o; $AR rcs "$PREFIX/lib/libsqlite3.a" sqlite3.o; cp sqlite3.h "$PREFIX/include/"; cd "$WORKDIR"; fi

# ---- PERBAIKAN: Build ICU4C dalam Dua Tahap ----
step "Build ICU4C (statis)"
if [ ! -f "$PREFIX/lib/libicuuc.a" ]; then
    ICU_VERSION="75.1"
    ICU_VERSION_US="75_1"
    ICU_SRC_DIR="icu"
    ICU_FILE="icu4c-${ICU_VERSION_US}-src.tgz"
    ICU_HOST_BUILD_DIR="$WORKDIR/icu-host-build"
    ICU_TARGET_BUILD_DIR="$WORKDIR/icu-target-build"

    [ ! -f "$ICU_FILE" ] && wget -q https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/${ICU_FILE}
    [ ! -d "$ICU_SRC_DIR" ] && tar -xzf "$ICU_FILE"

    # Tahap 1: Build untuk Host (x86_64) untuk menghasilkan alat bantu
    step "Build ICU4C - Tahap 1: Host Tools"
    mkdir -p "$ICU_HOST_BUILD_DIR" && cd "$ICU_HOST_BUILD_DIR"
    # PERBAIKAN: Reset variabel lingkungan agar menggunakan kompilator host (gcc)
    CC="gcc" CXX="g++" CFLAGS="" LDFLAGS="" CPPFLAGS="" ../$ICU_SRC_DIR/source/configure --prefix="$ICU_HOST_BUILD_DIR/install" --disable-samples --disable-tests
    CC="gcc" CXX="g++" make -j$(nproc)

    cd "$WORKDIR"

    # Tahap 2: Build untuk Target (ARM) menggunakan alat dari Tahap 1
    step "Build ICU4C - Tahap 2: Target Library"
    mkdir -p "$ICU_TARGET_BUILD_DIR" && cd "$ICU_TARGET_BUILD_DIR"
    ../$ICU_SRC_DIR/source/configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
        --with-cross-build="$ICU_HOST_BUILD_DIR" \
        --disable-shared --enable-static \
        --with-data-packaging=static \
        --disable-samples --disable-tests
    make -j$(nproc) && make install
    
    cd "$WORKDIR"
fi

# Verifikasi ICU
step "Verifikasi instalasi ICU"
if [ ! -f "$PREFIX/include/unicode/parseerr.h" ]; then
  echo -e "\n\e[1;31mKESALAHAN: Header ICU 'parseerr.h' tidak ditemukan.\e[0m"
  exit 1
else
  echo -e "\e[1;32mHeader ICU ditemukan.\e[0m"
fi

# Build libcurl
step "Build libcurl (statis)"
if [ ! -f "$PREFIX/lib/libcurl.a" ]; then
  CURL_VERSION="8.7.1"
  CURL_FILE="curl-${CURL_VERSION}.tar.xz"
  [ ! -f "$CURL_FILE" ] && wget -q https://curl.se/download/${CURL_FILE}
  tar -xf "$CURL_FILE" && cd "curl-${CURL_VERSION}"
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --with-ssl="$PREFIX" --without-zstd --disable-ldap
  make -j$(nproc) && make install
  cd "$WORKDIR"
fi

# Build PHP
step "Unduh dan konfigurasikan PHP"
PHP_SRC="php-$PHP_VERSION"
PHP_FILE="php-${PHP_VERSION}.tar.gz"
[ ! -d "$PHP_SRC" ] && {
  [ ! -f "$PHP_FILE" ] && wget -q https://github.com/vkyas/dengue/releases/download/php-8.4.8/php-${PHP_VERSION}.tar.gz
  tar -xzf "$PHP_FILE"
}
cd "$PHP_SRC"
[ -f "Makefile" ] && make distclean
./buildconf --force
./configure \
  --build=x86_64-pc-linux-gnu \
  --host="$HOST_TRIPLE" \
  --prefix="$OUTDIR" \
  --with-config-file-path="$OUTDIR/ini" \
  --with-config-file-scan-dir="$OUTDIR/conf.d" \
  --disable-all \
  --disable-phpdbg \
  --enable-cli \
  --enable-static \
  --enable-ctype=shared \
  --enable-dom=shared \
  --enable-filter=shared \
  --enable-json=shared \
  --enable-mysqlnd=shared \
  --enable-pdo=shared \
  --enable-session=shared \
  --enable-sockets=shared \
  --enable-sqlite3=shared,"$PREFIX" \
  --enable-xml=shared \
  --enable-simplexml=shared \
  --enable-xmlreader=shared \
  --enable-xmlwriter=shared \
  --enable-wddx=shared \
  --enable-xmlrpc=shared \
  --enable-reflection=shared \
  --enable-mbstring=shared \
  --enable-intl=shared \
  --enable-opcache=shared \
  --with-curl="$PREFIX" \
  --with-iconv="$PREFIX" \
  --with-openssl="$PREFIX" \
  --with-pdo-sqlite="$PREFIX" \
  --with-zlib="$PREFIX" \
  --with-libxml="$PREFIX" \
  --with-onig="$PREFIX" \
  --with-icu-dir="$PREFIX" \
  LIBS="-lz -lssl -lcrypto -liconv -lxml2 -lonig -licuuc -licui18n -licudata -lsqlite3 -lcurl" \
  LDFLAGS="$LDFLAGS" 2>&1 | tee configure.log

step "Build dan Install PHP"
make -j$(nproc) 2>&1 | tee install.log
make install 2>&1 | tee -a install.log
cd "$WORKDIR"

# Build Ekstensi PECL
PHP_EXTENSION_DIR="$OUTDIR/lib/php/extensions/no-debug-non-zts-$PHP_VERSION"
mkdir -p "$PHP_EXTENSION_DIR"

build_pecl_extension() {
  EXT_NAME="$1"
  EXT_VERSION="$2"
  EXT_URL="$3"
  step "Build $EXT_NAME-$EXT_VERSION"
  if [ ! -f "$PHP_EXTENSION_DIR/$EXT_NAME.so" ]; then
    EXT_FILE="${EXT_NAME}-${EXT_VERSION}.tgz"
    [ ! -f "$EXT_FILE" ] && wget -q "$EXT_URL"
    tar -xzf "$EXT_FILE" && cd "${EXT_NAME}-${EXT_VERSION}"
    "$OUTDIR/bin/phpize"
    ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
      CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
      --with-php-config="$OUTDIR/bin/php-config"
    make -j$(nproc) && make install
    cd "$WORKDIR"
  fi
}

build_pecl_extension "propro" "2.1.0" "https://pecl.php.net/get/propro-2.1.0.tgz"
build_pecl_extension "raphf" "2.0.1" "https://pecl.php.net/get/raphf-2.0.1.tgz"

# Finalisasi
step "Finalisasi dan strip"
$STRIP --strip-unneeded "$OUTDIR/bin/php" || true
find "$PHP_EXTENSION_DIR" -name "*.so" -exec $STRIP --strip-unneeded {} \; || true

# Setup php.ini
step "Membuat php.ini"
INI_DIR="$OUTDIR/ini"
mkdir -p "$INI_DIR"
cat > "$INI_DIR/php.ini" << 'EOF'
[PHP]
engine = On
precision = 14
output_buffering = 0
zlib.output_compression = Off
implicit_flush = On
serialize_precision = -1
disable_functions =
disable_classes =
expose_php = On
max_execution_time = 0
max_input_time = -1
memory_limit = 128M
error_reporting =
display_errors = STDOUT
display_startup_errors = Off
log_errors = Off
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
variables_order = EGPCS
request_order =
register_argc_argv = On
auto_globals_jit = On
post_max_size = 8M
default_mimetype = text/html
default_charset = UTF-8
doc_root = /data/adb/php7/files/www
user_dir = /data/adb/php7/files/bin
extension_dir = /data/adb/php7/files/bin
sys_temp_dir = /data/adb/php7/files/tmp
enable_dl = On
cgi.fix_pathinfo = 1
file_uploads = On
upload_tmp_dir = /data/adb/php7/files/tmp
upload_max_filesize = 2M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
session.auto_start = Off
session.cache_expire = 180
session.cache_limiter = nocache
session.cookie_httponly = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_secure = 0
session.gc_divisor = 100
session.gc_maxlifetime = 1440
session.gc_probability = 1
session.lazy_write = On
session.name = PHPSESSID
session.save_handler = files
session.serialize_handler = php
session.use_cookies = 1
session.use_only_cookies = 1
session.use_strict_mode = 0
extension=ctype.so
extension=curl.so
extension=dom.so
extension=filter.so
extension=intl.so
extension=json.so
extension=mbstring.so
extension=mysqlnd.so
extension=openssl.so
extension=pdo.so
extension=pdo_sqlite.so
extension=propro.so
extension=raphf.so
extension=reflection.so
extension=session.so
extension=simplexml.so
extension=sockets.so
extension=sqlite3.so
extension=wddx.so
extension=xml.so
extension=xmlreader.so
extension=xmlrpc.so
extension=xmlwriter.so
EOF

# Setup php.config
step "Membuat php.config"
CONFIG_DIR="$OUTDIR/scripts"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/php.config" << 'EOF'
#!/system/bin/sh

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Magisk, KernelSU or APatch busybox
if command_exists /data/adb/magisk/busybox; then
    busybox_path=/data/adb/magisk/busybox
elif command_exists /data/adb/ksu/bin/busybox; then
    busybox_path=/data/adb/ksu/bin/busybox
elif command_exists /data/adb/ap/bin/busybox; then
    busybox_path=/data/adb/ap/bin/busybox
else
    echo "No suitable busybox found. Exiting."
    exit 1
fi

# PHP7 FILES PATH
wserv_path="/data/adb/php7"

# WEBSERVER IP
wserv_ip="0.0.0.0"

# WEBSERVER PORT
wserv_port="80"

# PATH HTDOCS/WWW
www_path="${wserv_path}/files/www"

# PHP CONFIG
php_ini_conf="${wserv_path}/files/config/php.ini"

php_tmp_dir="${wserv_path}/files/tmp"
php_log_path="${php_tmp_dir}/php7.log"
php_pid_path="${php_tmp_dir}/php7.pid"

# TTYD CONFIG
ttyd_run="1"
ttyd_port="3001"
ttyd_firstcmd="sh /data/adb/php7/scripts/tmux_run"
ttyd_pid_path="${php_tmp_dir}/ttyd.pid"

${busybox_path} rxfetch 2>/dev/null
tmux_bin_path="/data/data/com.termux/files/usr/bin"
EOF
chmod +x "$CONFIG_DIR/php.config"

# Pengemasan
step "Pengemasan"
mkdir -p "$OUTDIR/data/adb/php7/files/www"
mkdir -p "$OUTDIR/data/adb/php7/files/bin"
mkdir -p "$OUTDIR/data/adb/php7/files/tmp"
mkdir -p "$OUTDIR/data/adb/php7/files/config"
mkdir -p "$OUTDIR/data/adb/php7/scripts"
mv "$INI_DIR/php.ini" "$OUTDIR/data/adb/php7/files/config/php.ini"
mv "$CONFIG_DIR/php.config" "$OUTDIR/data/adb/php7/scripts/php.config"
mv "$OUTDIR/lib/php/extensions" "$OUTDIR/data/adb/php7/files/bin/"
mv "$OUTDIR/bin" "$OUTDIR/data/adb/php7/files/"
TAR_FILE="$BASE_DIR/php-android-arm32-v${PHP_VERSION}.tar.gz"
tar -czvf "$TAR_FILE" -C "$OUTDIR" .

echo -e "\n\e[1;32m✅ Build selesai. File: $TAR_FILE\e[0m"
