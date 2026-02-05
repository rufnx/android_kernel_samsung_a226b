#!/usr/bin/env bash

# Exit on error and treat unset variables as errors
set -euo pipefail

################################################################################
# Color Definitions
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Logging Functions
################################################################################
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}######${NC} $1"
}

################################################################################
# Configuration
################################################################################
KDIR=$PWD
CLANG_DIR=$KDIR/clang
OUT_DIR=$KDIR/out
AK3_DIR=$KDIR/AK3
DEFCONFIG=rufnx_defconfig
DATE=$(date +%Y%m%d-%H%M)
ZIPNAME=AnyKernel3-a22x-$DATE.zip

################################################################################
# Toolchain Management
################################################################################
fetch_toolchain() {
    print_info "Fetching $1 to $2..."
    if curl -LSs https://raw.githubusercontent.com/rufnx/toolchain/README/toolchain | bash -s $1 $2; then
        print_info "$1 installed successfully"
    else
        print_error "Failed to fetch $1"
        exit 1
    fi
}

setup_toolchains() {
    print_header "Setting up toolchains"
    
    if [ ! -d $CLANG_DIR ]; then
        fetch_toolchain "clang-13" $CLANG_DIR
    else
        print_info "Clang toolchain already exists"
    fi
    
    export PATH=$CLANG_DIR/bin:$PATH
    
    if ! command -v clang &> /dev/null; then
        print_error "Clang not found in PATH"
        exit 1
    fi
    
    print_info "Toolchain: $(clang --version | head -n1)"
}

################################################################################
# Telegram Integration
################################################################################
push_to_telegram() {
    [ -z $BOT_TOKEN ] && return
    [ -z $CHAT_ID ] && return
    
    curl -s -F "document=@$1" \
         -F "chat_id=$CHAT_ID" \
         -F "caption=$2" \
         -F "parse_mode=Markdown" \
         "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" > /dev/null
}

################################################################################
# Build Configuration
################################################################################
setup_build_env() {
    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CC=clang
    export AR=llvm-ar
    export NM=llvm-nm
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export STRIP=llvm-strip
    export KCFLAGS=-w
    export KBUILD_OUTPUT=$OUT_DIR
}

get_build_args() {
    echo "-j$(nproc --all) \
          ARCH=arm64 \
          CROSS_COMPILE=aarch64-linux-gnu- \
          AR=llvm-ar \
          NM=llvm-nm \
          OBJCOPY=llvm-objcopy \
          OBJDUMP=llvm-objdump \
          STRIP=llvm-strip \
          KCFLAGS=-w \
          O=$OUT_DIR \
          CC=clang \
          CONFIG_SECTION_MISMATCH_WARN_ONLY=y"
}

################################################################################
# Kernel Build Process
################################################################################
configure_kernel() {
    print_header "Configuring kernel with $DEFCONFIG"
    
    if make -C $KDIR $(get_build_args) $DEFCONFIG; then
        print_info "Configuration completed successfully"
    else
        print_error "Configuration failed"
        exit 1
    fi
}

compile_kernel() {
    print_header "Building kernel"
    
    local start_time=$(date +%s)
    
    if make -C $KDIR $(get_build_args); then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        
        print_header "Build completed in ${minutes}m ${seconds}s"
        
        if [ -f $OUT_DIR/arch/arm64/boot/Image ] || [ -f $OUT_DIR/arch/arm64/boot/Image.gz ]; then
            print_info "Kernel image created successfully"
            ls -lh $OUT_DIR/arch/arm64/boot/Image* 2>/dev/null
        else
            print_warn "Kernel image not found in expected location"
            exit 1
        fi
    else
        print_error "Build failed"
        exit 1
    fi
}

################################################################################
# Package Creation
################################################################################
create_flashable_zip() {
    print_header "Creating flashable package"
    
    if [ ! -d $AK3_DIR ]; then
        print_info "Cloning AnyKernel3..."
        git clone --depth=1 --single-branch https://github.com/rufnx/AnyKernel3.git -b a22x $AK3_DIR
    fi
    
    print_info "Copying kernel image..."
    cp $OUT_DIR/arch/arm64/boot/Image.gz $AK3_DIR/
    
    print_info "Creating zip archive..."
    cd $AK3_DIR
    zip -r9 $ZIPNAME * -x .git README.md *placeholder
    
    if [ -f $ZIPNAME ]; then
        print_info "Package created: $ZIPNAME"
        ls -lh $ZIPNAME
    else
        print_error "Failed to create package"
        exit 1
    fi
}

################################################################################
# Notification
################################################################################
send_notification() {
    print_header "Sending build notification"
    
    local kver=$(strings $OUT_DIR/arch/arm64/boot/Image 2>/dev/null | grep "Linux version" | head -n1)
    local commit=$(git log --oneline -1)
    
    local caption="*Build Succes*
\`\`\`
$kver
\`\`\`
[commit]($commit)"
    
    if [ -f $AK3_DIR/$ZIPNAME ]; then
        push_to_telegram $AK3_DIR/$ZIPNAME "$caption"
        print_info "Notification sent"
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    print_header "Starting kernel build process"
    
    setup_toolchains
    setup_build_env
    configure_kernel
    compile_kernel
    create_flashable_zip
    send_notification
    
    print_header "All tasks completed successfully"
}

main
