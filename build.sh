#!/usr/bin/env bash

set -e

KERNEL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TOOLCHAIN=${KERNEL_DIR}/prebuilts
GZIP=${KERNEL_DIR}/out/arch/arm64/boot/Image.gz

if [ ! -d ${TOOLCHAIN} ]; then
    git clone --depth=1 --single-branch -b clang-13 \
        https://github.com/rufnx/toolchain.git ${TOOLCHAIN}
    ${TOOLCHAIN}/bin/clang --version
    export PATH=${TOOLCHAIN}/bin:${PATH}
fi

ARGS=(
    -j$(nproc --all)
    ARCH=arm64
    O=out
    CC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    KCFLAGS=-w
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make ${ARGS[@]} rufnx_defconfig
make ${ARGS[@]} | tee build.log

if [ -f ${GZIP} ]; then
    echo "==> Build success!"
else
    echo "==> Build failed, Image.gz not found"
    exit 1
fi
