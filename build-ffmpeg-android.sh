#!/usr/bin/env bash

set -e

export NDK="/c/Users/Yamin/AppData/Local/Android/Sdk/ndk/27.0.12077973"
export API=21
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/windows-x86_64

OUTPUT_DIR=$(pwd)/android
mkdir -p "$OUTPUT_DIR"

# FFmpeg version
FFMPEG_VERSION="n7.1.2"

build_ffmpeg() {
  ARCH=$1
  TARGET=$2
  CPU=$3
  NEON=$4

  echo "============================"
  echo " Building FFmpeg for $ARCH "
  echo "============================"

  PREFIX="$OUTPUT_DIR/$ARCH"

  export CC=$TOOLCHAIN/bin/$TARGET$API-clang
  export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
  export AR=$TOOLCHAIN/bin/llvm-ar
  
  # Use llvm-strip instead of architecture-specific strip
  export STRIP="$TOOLCHAIN/bin/llvm-strip.exe"
  
  # Use correct NM and skip checks
  export NM="$TOOLCHAIN/bin/llvm-nm.exe"
  export ac_cv_prog_NM="$TOOLCHAIN/bin/llvm-nm.exe"
  export ac_cv_prog_nm_works=yes
  export cross_compiling=yes
  
  export CFLAGS="-std=c11 -O2 -fPIC"
  export CXXFLAGS="-std=c++11" 
  export LDFLAGS="-pie"

  # Build configure command dynamically to handle empty NEON
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
    --enable-encoder=pcm_s16le,pcm_s24le,pcm_f32le \
    --enable-demuxer=mp3,aac,flac,ogg,wav,mp4,mov,matroska,avi,m4a,flv \
    --enable-muxer=wav \
    --enable-parser=mpegaudio,aac,flac,vorbis,opus \
    --enable-protocol=file,pipe \
    --enable-gpl \
    --enable-version3 \
    --enable-pthreads"
  
  # Only add NEON if it's not empty
  if [ -n "$NEON" ]; then
    CONFIGURE_CMD="$CONFIGURE_CMD $NEON"
  fi

  # Execute the configure command
  eval $CONFIGURE_CMD

  make clean
  make -j$(nproc)
  
  # FIX: Install with explicit strip command
  make install STRIP="$STRIP"
  
  echo "Built $ARCH successfully"
}

# ARM architectures (support NEON)
build_ffmpeg arm64 aarch64-linux-android armv8-a "--enable-neon"
build_ffmpeg arm armv7a-linux-androideabi armv7-a "--enable-neon"

# x86 architectures (NO NEON - it's ARM-only)
build_ffmpeg x86 i686-linux-android i686 ""
build_ffmpeg x86_64 x86_64-linux-android x86_64 ""

echo "Build completed!"