#!/usr/bin/env bash

set -e

export NDK="/c/Users/User/AppData/Local/Android/Sdk/ndk/27.0.12077973"
export API=21
export TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/windows-x86_64"

LAME_VERSION="3.100"
LAME_SOURCE="lame-${LAME_VERSION}"
LAME_URL="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/${LAME_SOURCE}.tar.gz"

LAME_OUTPUT_DIR=$(pwd)/android-lame
mkdir -p "$LAME_OUTPUT_DIR"

# Download LAME if not exists
if [ ! -d "$LAME_SOURCE" ]; then
    echo "Downloading LAME ${LAME_VERSION}..."
    wget "$LAME_URL" -O "${LAME_SOURCE}.tar.gz"
    tar -xzf "${LAME_SOURCE}.tar.gz"
fi

cd "$LAME_SOURCE"

build_lame() {
    ARCH=$1
    TARGET=$2
    HOST=$3
    SYSROOT="$TOOLCHAIN/sysroot"
    
    echo "============================"
    echo " Building LAME for $ARCH "
    echo "============================"
    
    PREFIX="$LAME_OUTPUT_DIR/$ARCH"
    mkdir -p "$PREFIX"
    
    export CC="$TOOLCHAIN/bin/${TARGET}${API}-clang"
    export CXX="$TOOLCHAIN/bin/${TARGET}${API}-clang++"
    export AR="$TOOLCHAIN/bin/llvm-ar"
    export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
    export STRIP="$TOOLCHAIN/bin/llvm-strip"
    
    export CFLAGS="-std=c99 -O2 -fPIC -DNDEBUG"
    export LDFLAGS="-pie"
    
    # Clean previous build
    make clean || true
    
    ./configure \
        --host="$HOST" \
        --prefix="$PREFIX" \
        --enable-static \
        --disable-shared \
        --disable-frontend \
        --disable-decoder \
        --enable-nasm \
        CC="$CC" \
        CXX="$CXX" \
        AR="$AR" \
        RANLIB="$RANLIB" \
        STRIP="$STRIP" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" \
        --with-sysroot="$SYSROOT"
    
    make -j$(nproc)
    make install
    
    echo "Built LAME for $ARCH"
}

# Build LAME for all architectures
build_lame arm armv7a-linux-androideabi arm-linux-androideabi
build_lame arm64 aarch64-linux-android aarch64-linux-android
build_lame x86 i686-linux-android i686-linux-android
build_lame x86_64 x86_64-linux-android x86_64-linux-android

echo "LAME cross-compilation completed!"