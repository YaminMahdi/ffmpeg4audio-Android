#!/usr/bin/env bash

set -e

export NDK="/c/Users/Yamin/AppData/Local/Android/Sdk/ndk/27.0.12077973"  # To Support 16 KB page sizes
export API=21
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/windows-x86_64

LAME_OUTPUT_DIR=$(pwd)/android-lame
FFMPEG_OUTPUT_DIR=$(pwd)/android

# Set full permissions on ALL directories
echo "Setting full permissions on all directories..."
mkdir -p "$LAME_OUTPUT_DIR"
mkdir -p "$FFMPEG_OUTPUT_DIR"
chmod -R 777 .

build_ffmpeg() {
  ARCH=$1
  TARGET=$2
  CPU=$3
  NEON=$4

  echo "============================"
  echo " Building FFmpeg for $ARCH "
  echo "============================"

  PREFIX="$FFMPEG_OUTPUT_DIR/$ARCH"
  LAME_PREFIX="$LAME_OUTPUT_DIR/$ARCH"

  export CC=$TOOLCHAIN/bin/$TARGET$API-clang
  export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
  export AR=$TOOLCHAIN/bin/llvm-ar

  # Use llvm-strip instead of architecture-specific strip
  export STRIP="$TOOLCHAIN/bin/llvm-strip.exe"

  # Use correct NM and skip checks
  export NM="$TOOLCHAIN/bin/llvm-nm.exe"

  export ac_cv_prog_NM="$NM"
  export ac_cv_prog_nm_works=yes
  export cross_compiling=yes

  # Export LAME paths for pkg-config
  export LAME_CFLAGS="-I$LAME_PREFIX/include"
  export LAME_LIBS="-L$LAME_PREFIX/lib -lmp3lame"

  # Set CFLAGS and LDFLAGS with LAME paths with 16 KB page sizes
  echo "Setting CFLAGS and LDFLAGS with LAME paths with 16 KB page sizes..."
  export CFLAGS="-std=c11 -O2 -fPIC -march=$CPU -DANDROID -I$LAME_PREFIX/include -Wl,-z,max-page-size=16384"
  export CXXFLAGS="-std=c++11 -fPIC -Wl,-z,max-page-size=16384"
  export LDFLAGS="-pie -L$LAME_PREFIX/lib -Wl,-z,max-page-size=16384"

  # Build configure command dynamically to handle empty NEON
  echo "Building configure command..."
  CONFIGURE_CMD="
  ./configure \
    --prefix=$PREFIX \
    --target-os=android \
    --arch=$ARCH \
    --cpu=$CPU \
    --enable-cross-compile \
    --cross-prefix=$TOOLCHAIN/bin/$TARGET- \
    --cc=$CC \
    --cxx=$CXX \
    --nm=$NM \
    --strip=$STRIP \
    --sysroot=$TOOLCHAIN/sysroot \
    --extra-cflags=\"$CFLAGS\" \
    --extra-ldflags=\"$LDFLAGS\" \
    --stdc=c11 \
    --enable-shared \
    --disable-static \
    --enable-pic \
    --enable-small \
    --disable-doc \
    --disable-programs \
    --enable-avcodec \
    --enable-avformat \
    --enable-avutil \
    --enable-swresample \
    --disable-avdevice \
    --disable-avfilter \
    --disable-postproc \
    --disable-swscale \
    --enable-optimizations \
    --disable-everything \
    --enable-decoder=mp3,aac,flac,ogg,vorbis,opus,ac3,eac3,wmav1,wmav2,alac,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_mulaw,pcm_alaw \
    --enable-encoder=libmp3lame,pcm_s16le,pcm_f32le \
    --enable-libmp3lame \
    --enable-demuxer=mp3,aac,flac,ogg,wav,m4a \
    --enable-muxer=mp3,wav \
    --enable-parser=mpegaudio,aac,flac,vorbis,opus \
    --enable-protocol=file,pipe \
    --enable-gpl \
    --enable-version3 \
    --enable-pthreads"

  # Disable x86 assembly to fix PIC errors
  if [ "$ARCH" = "x86" ] || [ "$ARCH" = "x86_64" ]; then
    CONFIGURE_CMD="$CONFIGURE_CMD --disable-x86asm --disable-inline-asm"
  fi

  if [ -n "$NEON" ]; then
    CONFIGURE_CMD="$CONFIGURE_CMD $NEON"
  fi

  # Execute the configure command
  echo "Configuring FFmpeg with LAME support..."
  eval $CONFIGURE_CMD

  # Clean previous build only if Makefile exists
  if [ -f "Makefile" ]; then
      make clean || true
  fi
  make -j$(nproc)

  # FIX: Install with explicit strip command
  echo "Installing FFmpeg with explicit strip command..."
  make install STRIP="$STRIP"

  echo "Built $ARCH successfully"
}

# ARM architectures (support NEON)
build_ffmpeg arm64 aarch64-linux-android armv8-a "--enable-neon"
build_ffmpeg arm armv7a-linux-androideabi armv7-a "--enable-neon"

# x86 architectures (NO NEON - it's ARM-only)
build_ffmpeg x86 i686-linux-android i686 ""
build_ffmpeg x86_64 x86_64-linux-android x86-64 ""

echo "Build completed!"