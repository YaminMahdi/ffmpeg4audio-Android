# FFmpeg Android Build Setup for Windows (MSYS2)

This guide walks you through building FFmpeg for Android on Windows using MSYS2.

## Prerequisites

### 1. Install MSYS2
a. Download and install MSYS2 from [https://www.msys2.org/](https://www.msys2.org/)
b. Open MSYS2 MINGW64

### 2. Setup FFmpeg Source
```bash
git clone https://github.com/YaminMahdi/ffmpeg4audio2wav-Android.git ffmpeg
cd ffmpeg
git remote add ffmpeg https://git.ffmpeg.org/ffmpeg.git
git fetch ffmpeg n7.1.2
git checkout -b n7.1.2-branch FETCH_HEAD
git merge master --allow-unrelated-histories
git checkout --theirs .
```

### 3. Install Required Packages
In your MSYS2 terminal, run these commands:

```bash
# Update package database
pacman -Syu

# Install build tools
pacman -S git make yasm pkg-config
pacman -S mingw-w64-x86_64-gcc
pacman -S --needed base-devel mingw-w64-x86_64-toolchain
```

## Building FFmpeg with LAME support

### 1. Set the NDK Path
Before running the build, edit `build-lame-android.sh` and `build-ffmpeg-android.sh` and change NDK path. Replace `Yamin` with your actual Windows username if different:

```bash
export NDK="/c/Users/Yamin/AppData/Local/Android/Sdk/ndk/27.0.12077973"
```

### 2. Make Build Scripts Executable
```bash
chmod +x build-lame-android.sh
chmod +x build-ffmpeg-android.sh
```

### 3. Run the Builds
```bash
./build-lame-android.sh
./build-ffmpeg-android.sh
```

## Output Libraries

After each build, you'll find the compiled libraries in:
- `ffmpeg/android/arm64/lib/`
- `ffmpeg/android/arm/lib/`
- `ffmpeg/android/x86/lib/`
- `ffmpeg/android/x86_64/lib/`

## Android Project Integration

### 1. Copy Libraries to Android Project

Create the following directory structure in your Android project:

```
app/
└── src/
    └── main/
        └── jniLibs/
            ├── arm64-v8a/
            ├── armeabi-v7a/
            ├── x86/
            └── x86_64/
```

### 2. Required Libraries

Each architecture folder should contain these shared libraries:
- `libavutil.so`
- `libavcodec.so`
- `libavformat.so`
- `libavfilter.so`

### 3. JNI Bridge

For running FFmpeg commands from Android, create a JNI bridge:

#### Create `src/main/cpp/ffmpeg_bridge.c`:
```c
#include <jni.h>
#include "ffmpeg.h"

JNIEXPORT jint JNICALL 
Java_com_example_ffmpeg_FFmpegLibs_run(JNIEnv *env, jclass clazz, jobjectArray cmdArray) {
    int argc = (*env)->GetArrayLength(env, cmdArray);
    char **argv = (char **) malloc(argc * sizeof(char *));
    
    for (int i = 0; i < argc; i++) {
        jstring string = (jstring)(*env)->GetObjectArrayElement(env, cmdArray, i);
        const char *raw = (*env)->GetStringUTFChars(env, string, 0);
        argv[i] = strdup(raw);
        (*env)->ReleaseStringUTFChars(env, string, raw);
    }
    
    int result = ffmpeg_main(argc, argv);
    
    for (int i = 0; i < argc; i++) {
        free(argv[i]);
    }
    free(argv);
    
    return result;
}
```

#### Kotlin Integration:
```kotlin
object FFmpegLibs {
    init {
        System.loadLibrary("avutil")
        System.loadLibrary("swresample")
        System.loadLibrary("avcodec")
        System.loadLibrary("avformat")
        System.loadLibrary("avfilter")
        System.loadLibrary("ffmpeg")
    }
    
    external fun run(cmd: Array<String>): Int
}
```

## Usage

Once integrated, you can use FFmpeg in your Android app:

```kotlin
val inputPath = File(x).path
val outputPath = File(y).path
val cmd = arrayOf(
    "ffmpeg",
    "-i", inputPath,
    "-ac", "2",
    "-c:a", "pcm_s16le", 
    "-y",
    outputPath
)
val result = FFmpegLibs.run(cmd)
```

## Troubleshooting

- Ensure all MSYS2 packages are up to date: `pacman -Syu`
- Verify Android NDK is properly configured
- Check that all required libraries are present in each architecture folder
- Make sure the build script has execute permissions

## Notes

- This setup targets FFmpeg version 7.1.2
- The build process creates libraries for all major Android architectures
- JNI bridge is optional but recommended for command-line FFmpeg usage