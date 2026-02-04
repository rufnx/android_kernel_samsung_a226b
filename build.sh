#!/usr/bin/env bash

# Exit on error and treat unset variables as errors
set -euo pipefail

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Directories
KDIR=$PWD
CLANG_DIR=$KDIR/clang
GCC_DIR=$KDIR/gcc
OUT_DIR=$KDIR/out
DEFCONFIG=rufnx_defconfig

# Toolchain download function
download_toolchain() {
    local toolchain_name=$1
    local install_dir=$2
    
    log_info "Downloading $toolchain_name to $install_dir..."
    if curl -LSs https://raw.githubusercontent.com/rufnx/toolchain/README/toolchain | bash -s "$toolchain_name" "$install_dir"; then
        log_info "$toolchain_name downloaded successfully"
    else
        log_error "Failed to download $toolchain_name"
        exit 1
    fi
}

# Check and download toolchains
if [ ! -d "$CLANG_DIR" ]; then
    download_toolchain "clang-11" "$CLANG_DIR"
else
    log_info "Clang toolchain already exists"
fi

if [ ! -d "$GCC_DIR" ]; then
    download_toolchain "aarch64-linux-android-4.9" "$GCC_DIR"
else
    log_info "GCC toolchain already exists"
fi

# Export PATH
export PATH=$CLANG_DIR/bin:$GCC_DIR/bin:$PATH

# Verify toolchains
if ! command -v clang &> /dev/null; then
    log_error "Clang not found in PATH"
    exit 1
fi

if ! command -v aarch64-linux-android- &> /dev/null; then
    log_error "GCC cross-compiler not found in PATH"
    exit 1
fi

# Build arguments
ARGS=(
    -j"$(nproc --all)"
    CROSS_COMPILE=aarch64-linux-android-
    CLANG_TRIPLE=aarch64-linux-gnu-
    ARCH=arm64
    KCFLAGS=-w
    O=out
    CC=clang
)

# Clean old build (optional - uncomment if needed)
# log_info "Cleaning old build..."
# make -C "$KDIR" "${ARGS[@]}" clean mrproper

# Configure kernel
log_info "Configuring kernel with $DEFCONFIG..."
if make -C "$KDIR" "${ARGS[@]}" CONFIG_SECTION_MISMATCH_WARN_ONLY=y $DEFCONFIG; then
    log_info "Kernel configuration completed"
else
    log_error "Kernel configuration failed"
    exit 1
fi

# Build kernel
log_info "Building kernel..."
START_TIME=$(date +%s)

if make -C "$KDIR" "${ARGS[@]}" CONFIG_SECTION_MISMATCH_WARN_ONLY=y; then
    END_TIME=$(date +%s)
    ELAPSED_TIME=$((END_TIME - START_TIME))
    log_info "Kernel build completed successfully in $((ELAPSED_TIME / 60)) minutes and $((ELAPSED_TIME % 60)) seconds"
    
    # Check for kernel image
    if [ -f "$OUT_DIR/arch/arm64/boot/Image" ] || [ -f "$OUT_DIR/arch/arm64/boot/Image.gz" ]; then
        log_info "Kernel image created successfully"
        ls -lh "$OUT_DIR/arch/arm64/boot/"
    else
        log_warn "Kernel image not found in expected location"
    fi
else
    log_error "Kernel build failed"
    exit 1
fi
