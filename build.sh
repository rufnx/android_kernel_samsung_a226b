#!/usr/bin/env bash

set -e

KERNEL_DIR=$(cd -- $(dirname -- ${BASH_SOURCE[0]}) && pwd)
TOOLCHAIN=$KERNEL_DIR/prebuilts
GZIP=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
ANYKERNEL_DIR=$KERNEL_DIR/AnyKernel3
ZIP_DIR=$KERNEL_DIR/out/zip

[ -z $BOT_TOKEN ] && echo "BOT_TOKEN not set"
[ -z $CHAT_ID ] && echo "CHAT_ID not set"

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
    msg=$(zcat $GZIP | strings | grep "Linux version")

    echo "\`\`\`
$msg
\`\`\`"
}

if [ ! -d $TOOLCHAIN ]; then
    wget "$(curl -s https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-15-link.txt)" -O zyc-clang.tar.gz
    mkdir $TOOLCHAIN && tar -xvf zyc-clang.tar.gz -C $TOOLCHAIN
    $TOOLCHAIN/bin/clang --version
    export PATH=$TOOLCHAIN/bin:$PATH
fi

ARGS=(
    -j$(nproc --all)
    O=out
    ARCH=arm64
    AR=llvm-ar
    NM=llvm-nm
    LD=ld.lld
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    CC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    KCFLAGS=-w
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make ${ARGS[@]} rufnx_defconfig
make ${ARGS[@]} | tee compile.log

if [ -f $GZIP ]; then
    echo "##############"
    echo "Build success!"
    echo "##############"

    # Clone AnyKernel3 if not exist
    [ ! -d $ANYKERNEL_DIR ] && git clone https://github.com/rufnx/AnyKernel3 -b a22x $ANYKERNEL_DIR

    # Prepare zip directory
    rm -rf $ZIP_DIR
    mkdir -p $ZIP_DIR
    cp -r $ANYKERNEL_DIR/* $ZIP_DIR/
    cp $GZIP $ZIP_DIR/

    # Create zip file
    zip_name=Kernel-$(date +%Y%m%d-%H%M).zip
    cd $ZIP_DIR
    zip -r9 $zip_name * -x .git README.md *placeholder
    cd $KERNEL_DIR

    # Send to Telegram
    message=$(build_message)
    send_telegram $ZIP_DIR/$zip_name "$message"
    echo "Kernel zip sent to Telegram successfully!"
else
    echo "##############"
    echo "Build failed! "
    echo "##############"

    # Send error log to Telegram
    grep "error" compile.log > error.log
    send_telegram error.log "Build failed!"

    exit 1
fi
