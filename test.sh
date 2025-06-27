#!/bin/bash

set -e
set -o pipefail

export NDK_VERSION="r26d"
export PHP_VERSION="8.4.8"
export API_LEVEL="22"
export HOST_TRIPLE="armv7a-linux-androideabi"

export BASE_DIR="$(pwd)"
export WORKDIR="$BASE_DIR/build-arm32"
export OUTDIR="$BASE_DIR/output-arm32"
export PREFIX="$WORKDIR/sysroot-arm32"
export LOG_FILE="$BASE_DIR/build.log"

rm -f "$LOG_FILE"
exec &> >(tee -a "$LOG_FILE")

step() { echo -e "\nSTEP: $1"; }

mkdir -p "$WORKDIR" "$OUTDIR" "$PREFIX"
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
export CFLAGS="--sysroot=$SYSROOT -fPIC -Os -I$PREFIX/include"
export LDFLAGS="--sysroot=$SYSROOT -L$PREFIX/lib -Wl,-rpath-link=$PREFIX/lib -pie"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

step "Build zlib"
if [ ! -f "$PREFIX/lib/libz.a" ]; then
  ZLIB_FILE="zlib-1.3.1.tar.gz"
  [ ! -f "$ZLIB_FILE" ] && wget -q https://zlib.net/zlib-1.3.1.tar.gz
  tar -xzf "$ZLIB_FILE" && cd zlib-1.3.1
  ./configure --prefix="$PREFIX" --static && make -j4 && make install
  cd "$WORKDIR"
fi

step "Build OpenSSL (shared, -fPIC)"
if [ ! -f "$PREFIX/lib/libssl.so" ]; then
  OPENSSL_FILE="openssl-3.3.1.tar.gz"
  [ ! -f "$OPENSSL_FILE" ] && wget -q https://www.openssl.org/source/openssl-3.3.1.tar.gz
  tar -xzf "$OPENSSL_FILE" && cd openssl-3.3.1
  ./Configure linux-armv4 \
    -D__ANDROID_API__=$API_LEVEL \
    --prefix="$PREFIX" \
    shared no-tests
  make -j4 && make install_sw
  cd "$WORKDIR"
fi

step "Build libiconv"
if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
  ICONV_FILE="libiconv-1.17.tar.gz"
  [ ! -f "$ICONV_FILE" ] && wget -q https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
  tar -xzf "$ICONV_FILE" && cd libiconv-1.17
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build libxml2"
if [ ! -f "$PREFIX/lib/libxml2.a" ]; then
  LIBXML2_FILE="libxml2-2.12.7.tar.xz"
  [ ! -f "$LIBXML2_FILE" ] && wget -q https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz
  tar -xf "$LIBXML2_FILE" && cd libxml2-2.12.7
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
    --disable-shared --enable-static --without-python \
    --with-zlib="$PREFIX" --without-lzma
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build Oniguruma"
if [ ! -f "$PREFIX/lib/libonig.a" ]; then
  ONIG_FILE="onig-6.9.9.tar.gz"
  [ ! -f "$ONIG_FILE" ] && wget -q https://github.com/kkos/oniguruma/releases/download/v6.9.9/onig-6.9.9.tar.gz
  tar -xzf "$ONIG_FILE" && cd onig-6.9.9
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build libev (untuk ev.so)"
if [ ! -f "$PREFIX/lib/libev.a" ]; then
  LIBEV_FILE="libev-4.33.tar.gz"
  [ ! -f "$LIBEV_FILE" ] && wget -q "http://dist.schmorp.de/libev/libev-4.33.tar.gz"
  tar -xzf "$LIBEV_FILE" && cd libev-4.33
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build libevent (untuk event.so)"
if [ ! -f "$PREFIX/lib/libevent_core.so" ]; then
  LIBEVENT_FILE="libevent-2.1.12-stable.tar.gz"
  [ ! -f "$LIBEVENT_FILE" ] && wget -q "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz"
  tar -xzf "$LIBEVENT_FILE" && cd libevent-2.1.12-stable
  # Perbarui config.sub dan config.guess
  wget -q -O config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
  wget -q -O config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
  chmod +x config.sub config.guess
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --enable-shared --disable-static \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  make -j4 && make install
  cp "$PREFIX/lib/libevent_core.so"* "$OUTDIR/lib/" || true
  cp "$PREFIX/lib/libevent.so"* "$OUTDIR/lib/" || true
  cd "$WORKDIR"
fi

step "Build libssh2 (untuk ssh2.so)"
if [ ! -f "$PREFIX/lib/libssh2.a" ]; then
  LIBSSH2_FILE="libssh2-1.11.0.tar.gz"
  [ ! -f "$LIBSSH2_FILE" ] && wget -q "https://www.libssh2.org/download/libssh2-1.11.0.tar.gz"
  tar -xzf "$LIBSSH2_FILE" && cd libssh2-1.11.0
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --with-openssl="$PREFIX"
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build libyaml (untuk yaml.so)"
if [ ! -f "$PREFIX/lib/libyaml.a" ]; then
  LIBYAML_FILE="yaml-0.2.5.tar.gz"
  [ ! -f "$LIBYAML_FILE" ] && wget -q "https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz"
  tar -xzf "$LIBYAML_FILE" && cd yaml-0.2.5
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build libxdiff (untuk xdiff.so)"
if [ ! -f "$PREFIX/lib/libxdiff.a" ]; then
  LIBXDIFF_FILE="libxdiff-0.23.tar.gz"
  [ ! -f "$LIBXDIFF_FILE" ] && wget -q "http://www.xmailserver.org/libxdiff-0.23.tar.gz"
  tar -xzf "$LIBXDIFF_FILE" && cd libxdiff-0.23
  # Perbarui config.sub dan config.guess
  wget -q -O config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
  wget -q -O config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
  chmod +x config.sub config.guess
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static
  make -j4 && make install
  cd "$WORKDIR"
fi

step "Build unixODBC (untuk libodbcpsql.so)"
if [ ! -f "$PREFIX/lib/libodbcpsql.so" ]; then
  ODBCPSQL_FILE="unixODBC-2.3.12.tar.gz"
  [ ! -f "$ODBCPSQL_FILE" ] && wget -q "http://www.unixodbc.org/unixODBC-2.3.12.tar.gz"
  tar -xzf "$ODBCPSQL_FILE" && cd unixODBC-2.3.12
  ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" --enable-shared --disable-static
  make -j4 && make install
  cp "$PREFIX/lib/libodbcpsql.so"* "$OUTDIR/lib/" || true
  cd "$WORKDIR"
fi

step "Unduh dan configure PHP"
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
    --with-config-file-path="$OUTDIR/ini" \
    --with-config-file-scan-dir="$OUTDIR/conf.d" \
    --disable-all \
    --disable-phpdbg \
    --enable-cli \
    --enable-shared \
    --with-zlib="$PREFIX" \
    --with-openssl="$PREFIX" \
    --with-libxml="$PREFIX" \
    --with-iconv="$PREFIX" \
    --enable-mbstring \
    --enable-ftp=shared \
    --enable-bcmath=shared \
    --enable-calendar=shared \
    --enable-ctype=shared \
    --enable-dom=shared \
    --enable-exif=shared \
    --enable-fileinfo=shared \
    --enable-filter=shared \
    --enable-posix=shared \
    --enable-session=shared \
    --enable-sockets=shared \
    --enable-tokenizer=shared \
    --enable-xml=shared \
    --enable-xmlreader=shared \
    --enable-xmlwriter=shared \
    --enable-simplexml=shared \
    --enable-opcache=shared \
    LIBS="-liconv -lxml2 -lz -lssl -lcrypto -lonig" \
    LDFLAGS="$LDFLAGS" 2>&1 | tee configure.log
fi

step "Build PHP"
if [ ! -f "$OUTDIR/bin/php" ]; then
  make -n | grep "clang.*php-cgi" >> "$LOG_FILE"
  make clean
  make -j$(nproc) V=1 2>&1 | tee install.log
  make install 2>&1 | tee -a install.log
fi
cd "$WORKDIR"

step "Build Ekstensi PECL"
PHP_EXTENSION_DIR="$OUTDIR/lib/php/extensions/$EXT_DIR"
mkdir -p "$PHP_EXTENSION_DIR"

build_pecl_extension() {
    EXT_NAME="$1"
    EXT_VERSION="$2"
    EXT_URL="$3"
    EXT_FILE="${EXT_NAME}-${EXT_VERSION}.tgz"
    step "Build $EXT_NAME-$EXT_VERSION"
    if [ ! -f "$PHP_EXTENSION_DIR/$EXT_NAME.so" ]; then
        [ ! -f "$EXT_FILE" ] && wget -q "$EXT_URL"
        tar -xzf "$EXT_FILE" && cd "${EXT_NAME}-${EXT_VERSION}"
        "$OUTDIR/bin/phpize"
        ./configure --host="$HOST_TRIPLE" --prefix="$PREFIX" \
            CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
            --with-php-config="$OUTDIR/bin/php-config"
        make -j4 && make install
        cd "$WORKDIR"
    fi
}

build_pecl_extension "bbcode" "1.0.3b1" "https://pecl.php.net/get/bbcode-1.0.3b1.tgz"
build_pecl_extension "eio" "3.1.3" "https://pecl.php.net/get/eio-3.1.3.tgz"
build_pecl_extension "ev" "1.1.6RC1" "https://pecl.php.net/get/ev-1.1.6RC1.tgz"
build_pecl_extension "event" "3.1.4" "https://pecl.php.net/get/event-3.1.4.tgz"
build_pecl_extension "id3" "0.2" "https://pecl.php.net/get/id3-0.2.tgz"
build_pecl_extension "judy" "1.0.2" "https://pecl.php.net/get/judy-1.0.2.tgz"
build_pecl_extension "lzf" "1.7.0" "https://pecl.php.net/get/lzf-1.7.0.tgz"
build_pecl_extension "mailparse" "3.1.6" "https://pecl.php.net/get/mailparse-3.1.6.tgz"
build_pecl_extension "oauth" "2.0.7" "https://pecl.php.net/get/oauth-2.0.7.tgz"
build_pecl_extension "quickhash" "1.1.1" "https://pecl.php.net/get/quickhash-1.1.1.tgz"
build_pecl_extension "rar" "4.2.0" "https://pecl.php.net/get/rar-4.2.0.tgz"
build_pecl_extension "recode" "0.2.0" "https://pecl.php.net/get/recode-0.2.0.tgz"
build_pecl_extension "rpmreader" "0.4" "https://pecl.php.net/get/rpmreader-0.4.tgz"
build_pecl_extension "spl_types" "0.4.0" "https://pecl.php.net/get/spl_types-0.4.0.tgz"
build_pecl_extension "ssh2" "1.4.1" "https://pecl.php.net/get/ssh2-1.4.1.tgz"
build_pecl_extension "stats" "2.0.3" "https://pecl.php.net/get/stats-2.0.3.tgz"
build_pecl_extension "stomp" "2.0.3" "https://pecl.php.net/get/stomp-2.0.3.tgz"
build_pecl_extension "weakref" "0.3.3" "https://pecl.php.net/get/weakref-0.3.3.tgz"
build_pecl_extension "xdiff" "2.1.1" "https://pecl.php.net/get/xdiff-2.1.1.tgz"
build_pecl_extension "xmldiff" "1.1.1" "https://pecl.php.net/get/xmldiff-1.1.1.tgz"
build_pecl_extension "yaml" "2.2.3" "https://pecl.php.net/get/yaml-2.2.3.tgz"
build_pecl_extension "yar" "2.3.2" "https://pecl.php.net/get/yar-2.3.2.tgz"

step "Finalisasi dan strip"
$STRIP --strip-unneeded "$OUTDIR/bin/php" || true
find "$OUTDIR" -name "*.so" -exec $STRIP --strip-unneeded {} \; || true

step "OpenSSL"
cp "$PREFIX/lib/libssl.so"* "$OUTDIR/lib/" 2>/dev/null || true
cp "$PREFIX/lib/libcrypto.so"* "$OUTDIR/lib/" 2>/dev/null || true

step "Setup php.ini"
INI="$OUTDIR/ini/php.ini"
mkdir -p "$OUTDIR/ini"
cp "$PHP_SRC/php.ini-production" "$INI"
EXT_DIR=$(find "$OUTDIR/lib/php/extensions" -type d -name "no-debug-non-zts-*" -exec basename {} \;)
echo -e "\ndate.timezone = UTC" >> "$INI"
echo "extension_dir = \"$OUTDIR/lib/php/extensions/$EXT_DIR\"" >> "$INI"
echo "extension=bbcode.so" >> "$INI"
echo "extension=ev.so" >> "$INI"
echo "extension=event.so" >> "$INI"
echo "extension=id3.so" >> "$INI"
echo "extension=judy.so" >> "$INI"
echo "extension=lzf.so" >> "$INI"
echo "extension=mailparse.so" >> "$INI"
echo "extension=oauth.so" >> "$INI"
echo "extension=quickhash.so" >> "$INI"
echo "extension=rar.so" >> "$INI"
echo "extension=recode.so" >> "$INI"
echo "extension=rpmreader.so" >> "$INI"
echo "extension=spl_types.so" >> "$INI"
echo "extension=ssh2.so" >> "$INI"
echo "extension=stats.so" >> "$INI"
echo "extension=stomp.so" >> "$INI"
echo "extension=weakref.so" >> "$INI"
echo "extension=xdiff.so" >> "$INI"
echo "extension=xmldiff.so" >> "$INI"
echo "extension=yaml.so" >> "$INI"
echo "extension=yar.so" >> "$INI"
echo "extension=ftp.so" >> "$INI"
echo "extension=bcmath.so" >> "$INI"
echo "extension=calendar.so" >> "$INI"
echo "extension=ctype.so" >> "$INI"
echo "extension=dom.so" >> "$INI"
echo "extension=exif.so" >> "$INI"
echo "extension=fileinfo.so" >> "$INI"
echo "extension=filter.so" >> "$INI"
echo "extension=posix.so" >> "$INI"
echo "extension=session.so" >> "$INI"
echo "extension=sockets.so" >> "$INI"
echo "extension=tokenizer.so" >> "$INI"
echo "extension=xml.so" >> "$INI"
echo "extension=xmlreader.so" >> "$INI"
echo "extension=xmlwriter.so" >> "$INI"
echo "extension=simplexml.so" >> "$INI"
echo "extension=opcache.so" >> "$INI"

step "List Ekstensi"
find "$OUTDIR/lib/php/extensions" -name "*.so" -exec basename {} \; | while read -r so_file; do
    case "$so_file" in
        bbcode.so) echo "$so_file          ← PECL: https://pecl.php.net/package/bbcode" ;;
        ev.so) echo "$so_file              ← PECL: libev event loop" ;;
        event.so) echo "$so_file           ← PECL: libevent bindings" ;;
        id3.so) echo "$so_file             ← PECL: tag parsing" ;;
        judy.so) echo "$so_file            ← PECL: Judy array bindings" ;;
        lzf.so) echo "$so_file             ← PECL: kompresi LZF" ;;
        mailparse.so) echo "$so_file       ← PECL: mail parsing" ;;
        oauth.so) echo "$so_file           ← PECL: OAuth 1.0" ;;
        quickhash.so) echo "$so_file       ← PECL: struktur hash performa tinggi" ;;
        rar.so) echo "$so_file             ← PECL: RAR archive" ;;
        recode.so) echo "$so_file          ← PECL: konversi encoding" ;;
        rpmreader.so) echo "$so_file       ← PECL: baca file RPM" ;;
        spl_types.so) echo "$so_file       ← PECL: SPL extension" ;;
        ssh2.so) echo "$so_file            ← PECL: libssh2 bindings" ;;
        stats.so) echo "$so_file           ← PECL: statistik matematis" ;;
        stomp.so) echo "$so_file           ← PECL: STOMP protocol" ;;
        weakref.so) echo "$so_file         ← PECL: referensi lemah" ;;
        xdiff.so) echo "$so_file           ← PECL: diff berbasis libxdiff" ;;
        xmldiff.so) echo "$so_file         ← PECL: XML diff" ;;
        yaml.so) echo "$so_file            ← PECL: YAML parsing" ;;
        yar.so) echo "$so_file             ← PECL: Yet Another RPC framework" ;;
        *) echo "$so_file" ;;
    done
find "$OUTDIR/lib" -name "libodbcpsql.so*" -exec basename {} \; | while read -r so_file; do
    echo "$so_file     ← Pustaka eksternal, bukan dari PHP"
done

step "Packaging"
TAR_FILE="$BASE_DIR/php-android-arm32.tar.gz"
[ ! -f "$TAR_FILE" ] && tar -czvf "$TAR_FILE" -C "$OUTDIR" .

echo -e "\n✅ Build selesai. File: $TAR_FILE"
