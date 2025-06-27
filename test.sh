#!/bin/bash

export NDK_VERSION="r26d"
export PHP_VERSION="8.4.8"
export API_LEVEL="22"
export HOST_TRIPLE="armv7a-linux-androideabi"

export BASE_DIR="$(pwd)"
export WORKDIR="$BASE_DIR/build-arm32"
export OUTDIR="$BASE_DIR/output-arm32/data/adb/php7/files"
export PREFIX="$WORKDIR/sysroot-arm32"
export LOG_FILE="$BASE_DIR/build.log"

rm -f "$LOG_FILE"
exec &> >(tee -a "$LOG_FILE")

step() { echo -e "\nSTEP: $1"; }

mkdir -p "$WORKDIR" "$OUTDIR/bin" "$OUTDIR/config" "$OUTDIR/tmp" "$OUTDIR/www" "$OUTDIR/scripts" "$PREFIX"
cd "$WORKDIR"

step "Mengunduh Android NDK"
NDK_DIR="android-ndk-$NDK_VERSION"
NDK_ZIP="$NDK_DIR-linux.zip"
[ ! -d "$NDK_DIR" ] && { [ ! -f "$NDK_ZIP" ] && wget -q https://dl.google.com/android/repository/$NDK_ZIP; unzip -q "$NDK_ZIP"; }
export NDK_HOME="$WORKDIR/$NDK_DIR"

step "Siapkan Toolchain"
export TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
export PATH="$TOOLCHAIN/bin:$PATH"
export CC="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${HOST_TRIPLE}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export SYSROOT="$TOOLCHAIN/sysroot"
export CFLAGS="--sysroot=$SYSROOT -fPIC -Os -I$PREFIX/include -static"
export LDFLAGS="--sysroot=$SYSROOT -L$PREFIX/lib -static"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# Build zlib
if [ ! -f "$PREFIX/lib/libz.a" ]; then
  ZLIB_FILE="zlib-1.3.1.tar.gz"
  [ ! -f "$ZLIB_FILE" ] && wget -q https://zlib.net/zlib-1.3.1.tar.gz
  tar -xzf "$ZLIB_FILE" && cd zlib-1.3.1
  ./configure --prefix="$PREFIX" --static && make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libpng (untuk gd)
if [ ! -f "$PREFIX/lib/libpng.a" ]; then
  LIBPNG_FILE="libpng-1.6.43.tar.gz"
  [ ! -f "$LIBPNG_FILE" ] && wget -q https://download.sourceforge.net/libpng/libpng-1.6.43.tar.gz
  tar -xzf "$LIBPNG_FILE" && cd libpng-1.6.43
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libjpeg (untuk gd)
if [ ! -f "$PREFIX/lib/libjpeg.a" ]; then
  LIBJPEG_FILE="jpegsrc.v9e.tar.gz"
  [ ! -f "$LIBJPEG_FILE" ] && wget -q http://www.ijg.org/files/jpegsrc.v9e.tar.gz
  tar -xzf "$LIBJPEG_FILE" && cd jpeg-9e
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libzip (untuk zip)
if [ ! -f "$PREFIX/lib/libzip.a" ]; then
  LIBZIP_FILE="libzip-1.10.1.tar.gz"
  [ ! -f "$LIBZIP_FILE" ] && wget -q https://libzip.org/download/libzip-1.10.1.tar.gz
  tar -xzf "$LIBZIP_FILE" && cd libzip-1.10.1
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --with-zlib="$PREFIX"
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build gmp
if [ ! -f "$PREFIX/lib/libgmp.a" ]; then
  GMP_FILE="gmp-6.3.0.tar.xz"
  [ ! -f "$GMP_FILE" ] && wget -q https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz
  tar -xf "$GMP_FILE" && cd gmp-6.3.0
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build OpenSSL (static)
if [ ! -f "$PREFIX/lib/libssl.a" ]; then
  OPENSSL_FILE="openssl-3.3.1.tar.gz"
  [ ! -f "$OPENSSL_FILE" ] && wget -q https://www.openssl.org/source/openssl-3.3.1.tar.gz
  tar -xzf "$OPENSSL_FILE" && cd openssl-3.3.1
  ./Configure linux-armv4 -D__ANDROID_API__=$API_LEVEL --prefix="$PREFIX" no-shared no-tests
  make -j$(nproc) V=1 && make install_sw
  cd "$WORKDIR"
fi

# Build libiconv (sudah statis)
if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
  ICONV_FILE="libiconv-1.17.tar.gz"
  [ ! -f "$ICONV_FILE" ] && wget -q https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
  tar -xzf "$ICONV_FILE" && cd libiconv-1.17
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libxml2 (sudah statis)
if [ ! -f "$PREFIX/lib/libxml2.a" ]; then
  LIBXML2_FILE="libxml2-2.12.7.tar.xz"
  [ ! -f "$LIBXML2_FILE" ] && wget -q https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz
  tar -xf "$LIBXML2_FILE" && cd libxml2-2.12.7
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --without-python --with-zlib="$PREFIX" --without-lzma
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build Oniguruma (sudah statis)
if [ ! -f "$PREFIX/lib/libonig.a" ]; then
  ONIG_FILE="onig-6.9.9.tar.gz"
  [ ! -f "$ONIG_FILE" ] && wget -q https://github.com/kkos/oniguruma/releases/download/v6.9.9/onig-6.9.9.tar.gz
  tar -xzf "$ONIG_FILE" && cd onig-6.9.9
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libev (sudah statis)
if [ ! -f "$PREFIX/lib/libev.a" ]; then
  LIBEV_FILE="libev-4.33.tar.gz"
  [ ! -f "$LIBEV_FILE" ] && wget -q "http://dist.schmorp.de/libev/libev-4.33.tar.gz"
  tar -xzf "$LIBEV_FILE" && cd libev-4.33
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libevent (static)
if [ ! -f "$PREFIX/lib/libevent_core.a" ]; then
  LIBEVENT_FILE="libevent-2.1.12-stable.tar.gz"
  [ ! -f "$LIBEVENT_FILE" ] && wget -q "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz"
  tar -xzf "$LIBEVENT_FILE" && cd libevent-2.1.12-stable
  wget -q -O config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
  wget -q -O config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
  chmod +x config.sub config.guess
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libssh2 (sudah statis)
if [ ! -f "$PREFIX/lib/libssh2.a" ]; then
  LIBSSH2_FILE="libssh2-1.11.0.tar.gz"
  [ ! -f "$LIBSSH2_FILE" ] && wget -q "https://www.libssh2.org/download/libssh2-1.11.0.tar.gz"
  tar -xzf "$LIBSSH2_FILE" && cd libssh2-1.11.0
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --with-openssl="$PREFIX"
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libyaml (sudah statis)
if [ ! -f "$PREFIX/lib/libyaml.a" ]; then
  LIBYAML_FILE="yaml-0.2.5.tar.gz"
  [ ! -f "$LIBYAML_FILE" ] && wget -q "https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz"
  tar -xzf "$LIBYAML_FILE" && cd yaml-0.2.5
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libxdiff (sudah statis)
if [ ! -f "$PREFIX/lib/libxdiff.a" ]; then
  LIBXDIFF_FILE="libxdiff-0.23.tar.gz"
  [ ! -f "$LIBXDIFF_FILE" ] && wget -q "http://www.xmailserver.org/libxdiff-0.23.tar.gz"
  tar -xzf "$LIBXDIFF_FILE" && cd libxdiff-0.23
  wget -q -O config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
  wget -q -O config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
  chmod +x config.sub config.guess
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build unixODBC (static)
if [ ! -f "$PREFIX/lib/libodbc.a" ]; then
  ODBCPSQL_FILE="unixODBC-2.3.12.tar.gz"
  [ ! -f "$ODBCPSQL_FILE" ] && wget -q "http://www.unixodbc.org/unixODBC-2.3.12.tar.gz"
  tar -xzf "$ODBCPSQL_FILE" && cd unixODBC-2.3.12
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build libcurl (sudah statis)
if [ ! -f "$PREFIX/lib/libcurl.a" ]; then
  CURL_FILE="curl-8.7.1.tar.xz"
  [ ! -f "$CURL_FILE" ] && curl -LO https://curl.se/download/curl-8.7.1.tar.xz
  tar -xf "$CURL_FILE" && cd curl-8.7.1
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static \
    --with-ssl="$PREFIX" --without-zstd --disable-ldap
  make -j$(nproc) V=1 && make install
  cd "$WORKDIR"
fi

# Build PHP dengan semua ekstensi statis
PHP_SRC="php-$PHP_VERSION"
PHP_FILE="php-${PHP_VERSION}.tar.gz"
if [ ! -d "$PHP_SRC" ]; then
  [ ! -f "$PHP_FILE" ] && wget -q https://github.com/vkyas/dengue/releases/download/php-8.4.8/php-${PHP_VERSION}.tar.gz
  tar -xzf "$PHP_FILE"
fi
cd "$PHP_SRC"

if [ ! -f "Makefile" ]; then
  ./buildconf --force
  ./configure \
    --build=x86_64-pc-linux-gnu \
    --host="$HOST_TRIPLE" \
    --prefix="$OUTDIR" \
    --with-config-file-path="$OUTDIR/config" \
    --with-config-file-scan-dir="$OUTDIR/config/conf.d" \
    --disable-all \
    --disable-phpdbg \
    --enable-cli \
    --disable-shared --enable-static \
    --with-zlib="$PREFIX" \
    --with-openssl="$PREFIX" \
    --with-libxml="$PREFIX" \
    --with-iconv="$PREFIX" \
    --with-png="$PREFIX" \
    --with-jpeg="$PREFIX" \
    --with-libzip="$PREFIX" \
    --with-gmp="$PREFIX" \
    --enable-mbstring \
    --enable-ftp \
    --enable-bcmath \
    --enable-calendar \
    --enable-ctype \
    --enable-dom \
    --enable-exif \
    --enable-fileinfo \
    --enable-filter \
    --enable-posix \
    --enable-session \
    --enable-sockets \
    --enable-tokenizer \
    --enable-xml \
    --enable-xmlreader \
    --enable-xmlwriter \
    --enable-simplexml \
    --enable-opcache \
    --enable-gd \
    --enable-gettext \
    --enable-zip \
    --enable-gmp \
    --enable-rar \
    --enable-bbcode \
    --enable-eio \
    --enable-ev \
    --enable-event \
    --enable-id3 \
    --enable-judy \
    --enable-lzf \
    --enable-mailparse \
    --enable-oauth \
    --enable-quickhash \
    --enable-recode \
    --enable-rpmreader \
    --enable-spl_types \
    --enable-ssh2 \
    --enable-stats \
    --enable-stomp \
    --enable-weakref \
    --enable-xdiff \
    --enable-xmldiff \
    --enable-yaml \
    --enable-yar \
    LIBS="-liconv -lxml2 -lz -lssl -lcrypto -lonig -levent_core -lev -lssh2 -lyaml -lxdiff -lodbc -lpng -ljpeg -lzip -lgmp" \
    LDFLAGS="$LDFLAGS -static" \
    2>&1 | tee configure.log
fi

step "Build PHP"
if [ ! -f "$OUTDIR/bin/php" ]; then
  make -n | grep "clang.*php-cgi" >> "$LOG_FILE"
  make clean
  make -j$(nproc) V=1 2>&1 | tee install.log
  make install 2>&1 | tee -a install.log
fi
cd "$WORKDIR"

step "Finalisasi dan strip"
$STRIP --strip-unneeded "$OUTDIR/bin/php" || true

step "Setup php.ini"
INI="$OUTDIR/config/php.ini"
cat > "$INI" << 'EOF'
[PHP]

;;;;;;;;;;;;;;;;;;;;
; Language Options ;
;;;;;;;;;;;;;;;;;;;;

engine = On
precision = 12
output_buffering = Off
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 100
disable_functions =
disable_classes =
expose_php = On

;;;;;;;;;;;;;;;;;;;
; Resource Limits ;
;;;;;;;;;;;;;;;;;;;

max_execution_time = 30
max_input_time = 60
memory_limit = 512M

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Error handling and logging ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT
display_errors = On
display_startup_errors = Off
log_errors = Off
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off

;;;;;;;;;;;;;;;;;
; Data Handling ;
;;;;;;;;;;;;;;;;;

variables_order = "EGPCS"
request_order = "GP"
register_argc_argv = On
auto_globals_jit = On
post_max_size = 256M
default_mimetype = "text/html"

;;;;;;;;;;;;;;;;;;;;;;;;;
; Paths and Directories ;
;;;;;;;;;;;;;;;;;;;;;;;;;

doc_root = "/data/adb/php7/files/www"
user_dir = "/data/adb/php7/files/bin"
sys_temp_dir = "/data/adb/php7/files/tmp"
enable_dl = Off
cgi.fix_pathinfo = 1

;;;;;;;;;;;;;;;;
; File Uploads ;
;;;;;;;;;;;;;;;;

file_uploads = On
upload_tmp_dir = "/data/adb/php7/files/tmp"
upload_max_filesize = 27856M
max_file_uploads = 200

;;;;;;;;;;;;;;;;;;
; Fopen wrappers ;
;;;;;;;;;;;;;;;;;;

allow_url_fopen = On
allow_url_include = Off
EOF

step "Setup php7.sh"
cat > "$OUTDIR/scripts/php7.sh" << 'EOF'
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

/data/adb/php7/files/bin/rxfetch 2>/dev/null
tmux_bin_path="/data/data/com.termux/files/usr/bin"

# Jalankan PHP CLI atau server (contoh)
${wserv_path}/files/bin/php -S ${wserv_ip}:${wserv_port} -t ${www_path} -c ${php_ini_conf} &
echo $! > ${php_pid_path}
EOF
chmod +x "$OUTDIR/scripts/php7.sh"

step "Verifikasi Build Statis"
ldd "$OUTDIR/bin/php" || echo "Biner statis: tidak ada dependensi dinamis."

step "Packaging"
TAR_FILE="$BASE_DIR/php-android-arm32.tar.gz"
[ ! -f "$TAR_FILE" ] && tar -czvf "$TAR_FILE" -C "$BASE_DIR/output-arm32" .

echo -e "\n✅ Build selesai. File: $TAR_FILE"
