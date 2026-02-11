#!/usr/bin/env bash

set -e

KERNEL_DIR=$(cd -- $(dirname -- ${BASH_SOURCE[0]}) && pwd)
TOOLCHAIN=${KERNEL_DIR}/prebuilts
GZIP=${KERNEL_DIR}/out/arch/arm64/boot/Image.gz

if [ ! -d ${TOOLCHAIN} ]; then
    wget "$(curl -s https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt)" -O "zyc-clang.tar.gz"
    mkdir ${TOOLCHAIN} && tar -xvf zyc-clang.tar.gz -C ${TOOLCHAIN}
    ${TOOLCHAIN}/bin/clang --version
    export PATH=${TOOLCHAIN}/bin:${PATH}
fi

ARGS=(
    make -j$(nproc --all)
    O=out
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    AR=llvm-ar
    NM=llvm-nm
    LD=ld.lld
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    CC=clang
    DTC_EXT=dtc
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    KCFLAGS=-w
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make ARCH=arm64 O=out rufnx_defconfig
make ${ARGS[@]} | tee compile.log

if [ -f ${GZIP} ]; then
    echo "##############" 
    echo "Build success!"
    echo "##############"
else
    echo "##############"
    echo "Build failed! "
    echo "##############"
    exit 1
fi
