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
    \`\`\`"
}

if [ ! -d $TOOLCHAIN/clang ]; then
    git clone https://github.com/rufnx/toolchain.git --depth=1 -b clang-11 $TOOLCHAIN/clang
    $TOOLCHAIN/clang/bin/clang --version
fi

if [ ! -d $TOOLCHAIN/gcc ]; then
    git clone https://github.com/rufnx/toolchain.git --depth=1 -b aarch64-linux-android-4.9 $TOOLCHAIN/gcc
fi

export PATH=$TOOLCHAIN/clang/bin:$TOOLCHAIN/gcc/bin$PATH

ARGS=(
    -j$(nproc --all)
    O=out
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CROSS_COMPILE=aarch64-linux-android-
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make ${ARGS[@]} rufnx_defconfig
make ${ARGS[@]} | tee compile.log

if [ -f $GZIP ]; then
    echo "########################"
    echo "Build success!"
    echo "########################"

    # Clone AnyKernel3 if not exist
    [ ! -d $ANYKERNEL_DIR ] && git clone https://github.com/rufnx/AnyKernel3 -b a22x $ANYKERNEL_DIR

    # Prepare zip directory
    rm -rf $ZIP_DIR
    mkdir -p $ZIP_DIR
    cp -r $ANYKERNEL_DIR/* $ZIP_DIR/
    cp $GZIP $ZIP_DIR/

    # Create zip file
    ZIP_NAME=A226B-$(date +%Y%m%d-%H%M).zip
    cd $ZIP_DIR
    zip -r9 $ZIP_NAME . -x .git README.md *placeholder
    cd $KERNEL_DIR

    if [ -z "$BOT_TOKEN" ]; then
      echo "BOT_TOKEN kosong, skip kirim Telegram"
      return 0
    else
      msg=$(build_message)
      send_telegram "$ZIP_DIR/$ZIP_NAME" "$msg"
      echo "Kernel zip sent to Telegram successfully!"
    fi
else
    echo "########################"
    echo "Build failed! "
    echo "########################"

    # Send error log to Telegram & exit
    send_telegram compile.log "Build failed!"
    exit 1
fi
