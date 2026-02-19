#!/usr/bin/env bash

set -e

KERNEL_DIR=$(cd -- $(dirname -- ${BASH_SOURCE[0]}) && pwd)
TOOLCHAIN=$KERNEL_DIR/prebuilts
GZIP=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
ANYKERNEL_DIR=$KERNEL_DIR/AnyKernel3
ZIP_DIR=$KERNEL_DIR/out/zip

export KBUILD_BUILD_USER=rufnx
export KBUILD_BUILD_HOST=rufnxprjkt

export ANDROID_MAJOR_VERSION=r
export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

BUILD_START=$(date +%s)

function send_telegram() {
    local file=$1
    local caption=$2

    curl -F document=@$file \
         -F chat_id=$CHAT_ID \
         -F parse_mode=Markdown \
         -F caption="$caption" \
         https://api.telegram.org/bot$BOT_TOKEN/sendDocument
}

function build_message() {
    local msg=$(zcat $GZIP | strings | grep "Linux version")
    echo "
\`\`\`
$msg
Build Time: $BUILD_TIME
\`\`\`"
}

if [ ! -d $TOOLCHAIN/clang ]; then
    git clone https://github.com/rufnx/toolchain.git --depth=1 -b clang-11 $TOOLCHAIN/clang
    $TOOLCHAIN/clang/bin/clang --version
fi

if [ ! -d $TOOLCHAIN/gcc ]; then
    git clone https://github.com/rufnx/toolchain.git --depth=1 -b aarch64-linux-android-4.9 $TOOLCHAIN/gcc
fi

ARGS=(
    -j$(nproc --all)
    O=out
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC=$TOOLCHAIN/clang/bin/clang
    CROSS_COMPILE=$TOOLCHAIN/gcc/bin/aarch64-linux-android-
    CLANG_TRIPLE=aarch64-linux-gnu-
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make ${ARGS[@]} rufnx_defconfig
make ${ARGS[@]} | tee compile.log

BUILD_END=$(date +%s)
DIFF=$((BUILD_END - BUILD_START))
BUILD_TIME=$(printf '%02dh:%02dm:%02ds' $((DIFF/3600)) $((DIFF%3600/60)) $((DIFF%60)))

if [ -f $GZIP ]; then
    echo "########################"
    echo "Build success!"
    echo "Time: $BUILD_TIME"
    echo "########################"

    [ ! -d $ANYKERNEL_DIR ] && git clone https://github.com/rufnx/AnyKernel3 -b a22x $ANYKERNEL_DIR

    rm -rf $ZIP_DIR
    mkdir -p $ZIP_DIR
    cp -r $ANYKERNEL_DIR/* $ZIP_DIR/
    cp $GZIP $ZIP_DIR/

    ZIP_NAME=A226B-$(date +%Y%m%d-%H%M).zip
    cd $ZIP_DIR
    zip -r9 $ZIP_NAME . -x .git README.md *placeholder
    cd $KERNEL_DIR

    if [ -z "$BOT_TOKEN" ]; then
        echo "BOT_TOKEN kosong, skip kirim Telegram"
    else
        msg=$(build_message)
        send_telegram "$ZIP_DIR/$ZIP_NAME" "$msg"
        echo "Kernel zip sent to Telegram!"
    fi

else
    echo "########################"
    echo "Build failed!"
    echo "Time: $BUILD_TIME"
    echo "########################"

    if [ ! -z "$BOT_TOKEN" ]; then
        send_telegram compile.log "Build failed!\nTime: $BUILD_TIME"
    fi
    exit 1
fi
