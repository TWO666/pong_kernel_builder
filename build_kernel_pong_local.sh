#!/bin/bash
set -e
START_TIME=$(date +%s)
echo "===== Build started at: $(date) ====="
echo

# ===== Get script directory =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== Set custom parameters =====
echo "===== Nothing Phone 2 (5.10) KernelSU Local Build Script (Clang 20) - No Fake Timestamps ====="
echo ">>> Reading user configuration..."

# Default values derived from workflow
ANDROID_VERSION="android12"
KERNEL_VERSION="5.10"

read -p "KSU type (sukisu/ksunext/mksu/ksu, default: sukisu): " KSU_TYPE
KSU_TYPE=${KSU_TYPE:-sukisu}

read -p "Enable KPM (only for SukiSU)? (y/n, default: n): " USE_KPM
USE_KPM=${USE_KPM:-n}

# Set KSU type names
case "$KSU_TYPE" in
  sukisu)
    KSU_BRANCH="SukiSU Ultra"
    KSU_TYPENAME="SukiSU"
    ;;
  ksunext)
    KSU_BRANCH="KernelSU Next"
    KSU_TYPENAME="KSUNext"
    ;;
  mksu)
    KSU_BRANCH="MKSU"
    KSU_TYPENAME="MKSU"
    ;;
  ksu)
    KSU_BRANCH="KernelSU (Official)"
    KSU_TYPENAME="KSU"
    ;;
  *)
    echo "Error: Invalid KSU type"
    exit 1
    ;;
esac

if [[ "$USE_KPM" == "y" || "$USE_KPM" == "Y" ]] && [[ "$KSU_TYPE" != "sukisu" ]]; then
  echo "Warning: KPM only works with SukiSU, automatically disabled."
  USE_KPM="n"
fi

echo
echo "===== Configuration Info ====="
echo "Device: Nothing Phone 2"
echo "Kernel Version: $KERNEL_VERSION"
echo "KSU Type: $KSU_BRANCH"
echo "Enable KPM: $USE_KPM"
echo "=============================="
echo

# ===== Create working directory =====
WORKDIR="$SCRIPT_DIR"
# Clean old working directory
if [[ -d ./kernel_workspace/common ]]; then
  cd kernel_workspace
  rm -rf AnyKernel3 KernelSU* SukiSU_patch build-tools clang20 kernel_patches susfs4ksu *.sh
else
  rm -rf kernel_workspace
  mkdir kernel_workspace
  cd kernel_workspace
fi

# ===== Install build dependencies =====
echo ">>> Installing build dependencies..."
echo "Sudo permission required to install dependency packages..."
sudo apt-get update
sudo apt-get install --no-install-recommends -y \
    curl bison flex binutils git zip perl make gcc \
    python3 python-is-python3 bc libssl-dev libelf-dev aria2 unzip cpio ccache

# ===== Initialize kernel source and toolchain =====
echo ">>> Initializing kernel source and toolchain..."

echo ">>> Cloning Nothing Phone kernel source..."
if [[ -d common ]]; then
  cd common
  git restore .
  git clean -fd
  git pull
  cd ..
else
  git clone --depth=1 -b dev https://github.com/TWO666/hellboy017_kernel_pong.git common &
fi

echo ">>> Downloading Clang 20 toolchain..."
mkdir -p clang20
if [[ ! -f clang.zip ]]; then
  aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang20-r547379/clang-r547379.zip -o clang.zip &
fi

echo ">>> Downloading build tools (build-tools.zip)..."
if [[ ! -f build-tools.zip ]]; then
  aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang20-r547379/build-tools.zip -o build-tools.zip &
fi

wait
echo ">>> Extracting toolchain..."
unzip -q clang.zip -d clang20
unzip -q build-tools.zip

echo ">>> Nothing Phone kernel source and toolchain initialization completed!"

# ===== Clear abi files and remove -dirty suffix =====
echo ">>> Clearing ABI files and removing dirty suffix..."
rm common/android/abi_gki_protected_exports_* || true

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== Pull KSU and set version number =====
export KSU_VERSION
if [[ "$KSU_TYPE" == "sukisu" ]]; then
  echo ">>> Pulling SukiSU-Ultra and setting version..."
  curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/refs/heads/main/kernel/setup.sh" | bash -s susfs-main
  cd KernelSU
  
  # === SukiSU Ultra version number setup ===
  GIT_COMMIT_HASH=$(git rev-parse --short=8 HEAD)
  echo "Current commit hash: $GIT_COMMIT_HASH"
  
  # Get API version
  for i in {1..3}; do
    KSU_API_VERSION=$(curl -s "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/susfs-main/kernel/Makefile" | grep -m1 "KSU_VERSION_API :=" | awk -F'= ' '{print $2}' | tr -d '[:space:]')
    [ -n "$KSU_API_VERSION" ] && break || sleep 1
  done
  [ -z "$KSU_API_VERSION" ] && KSU_API_VERSION="3.1.7"
  echo "KSU_API_VERSION=$KSU_API_VERSION"
  
  # Set version definitions
  VERSION_DEFINITIONS=$'define get_ksu_version_full\nv\\$1-'"$GIT_COMMIT_HASH"$'@nothing\nendef\n\nKSU_VERSION_API := '"$KSU_API_VERSION"$'\nKSU_VERSION_FULL := v'"$KSU_API_VERSION"$'-'"$GIT_COMMIT_HASH"$'@nothing'
  
  sed -i '/define get_ksu_version_full/,/endef/d' kernel/Makefile
  sed -i '/KSU_VERSION_API :=/d' kernel/Makefile
  sed -i '/KSU_VERSION_FULL :=/d' kernel/Makefile
  
  awk -v def="$VERSION_DEFINITIONS" '
    /REPO_OWNER :=/ {print; print def; inserted=1; next}
    1
    END {if (!inserted) print def}
  ' kernel/Makefile > kernel/Makefile.tmp && mv kernel/Makefile.tmp kernel/Makefile
  
  KSU_VERSION=$(expr $(git rev-list --count main) + 37185 2>/dev/null || echo 114514)
  export KSU_VERSION
  
  echo "SukiSU version: v${KSU_API_VERSION}-${GIT_COMMIT_HASH}@nothing"
  echo "KSUVER (for zip): $KSU_VERSION"
  
  cd .. # Return to kernel_workspace
elif [[ "$KSU_TYPE" == "ksunext" ]]; then
  echo ">>> Pulling KernelSU Next and setting version..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs
  cd KernelSU-Next
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=next&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 10200)
  export KSU_VERSION
  sed -i "s/DKSU_VERSION=11998/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile
  echo "KernelSU Next version set to: $KSU_VERSION"
  cd .. # Return to kernel_workspace
elif [[ "$KSU_TYPE" == "mksu" ]]; then
  echo ">>> Pulling MKSU (5ec1cff/KernelSU) and setting version..."
  curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/5ec1cff/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 20000)
  export KSU_VERSION
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile
  echo "MKSU version: $KSU_VERSION"
  cd .. # Return to kernel_workspace
else
  echo ">>> Pulling official KernelSU (tiann/KernelSU) and setting version..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 20000)
  export KSU_VERSION
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile
  echo "Official KernelSU version: $KSU_VERSION"
  cd .. # Return to kernel_workspace
fi

# ===== Apply KernelSU & SUSFS patches =====
echo ">>> Applying SUSFS&hook patches..."

if [[ "$KSU_TYPE" == "sukisu" ]]; then
  echo ">>> Adding SukiSU Ultra patches..."
  git clone https://github.com/ShirkNeko/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION} --depth=1
  git clone https://github.com/ShirkNeko/SukiSU_patch.git --depth=1
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cp ./SukiSU_patch/69_hide_stuff.patch ./common/
  cd ./common
  patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
  patch -p1 < 69_hide_stuff.patch || true
elif [[ "$KSU_TYPE" == "ksunext" ]]; then
  echo ">>> Adding KernelSU Next patches..."
  git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION}
  # Since KernelSU Next has not been updated to adapt susfs 2.0.0, rollback to susfs 1.5.12
  cd susfs4ksu && git checkout 8a76ba240d1f7315352b49d97d854a4b166e5b47 && cd ..
  git clone https://github.com/WildKernels/kernel_patches.git --depth=1
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cp ./kernel_patches/next/scope_min_manual_hooks_v1.5.patch ./common/
  cp ./kernel_patches/69_hide_stuff.patch ./common/
  cd ./common
  patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
  patch -p1 -N -F 3 < scope_min_manual_hooks_v1.5.patch || true
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
  # Add WildKSU manager support for KernelSU Next
  cd ./drivers/kernelsu
  wget https://github.com/WildKernels/kernel_patches/raw/refs/heads/main/next/susfs_fix_patches/v1.5.12/fix_apk_sign.c.patch
  patch -p2 -N -F 3 < fix_apk_sign.c.patch || true
  cd ../../
elif [[ "$KSU_TYPE" == "mksu" ]]; then
  echo ">>> Adding patches for MKSU (5ec1cff/KernelSU)..."
  git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION} --depth=1
  git clone https://github.com/ShirkNeko/SukiSU_patch.git --depth=1
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cp ./SukiSU_patch/69_hide_stuff.patch ./common/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
  # Fix susfs 2.0.0 patches for MKSU
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/mksu_supercalls.patch
  patch -p1 < mksu_supercalls.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/fix_umount.patch
  patch -p1 < fix_umount.patch || true
  cd ../common
  patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
else
  echo ">>> Adding patches for official KernelSU (tiann/KernelSU)..."
  git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION} --depth=1
  git clone https://github.com/ShirkNeko/SukiSU_patch.git --depth=1
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cp ./SukiSU_patch/69_hide_stuff.patch ./common/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/fix_umount.patch
  patch -p1 < fix_umount.patch || true
  cd ../common
  patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
fi

cd ../ # Return to kernel_workspace

# ===== Add defconfig configuration items =====
echo ">>> Adding defconfig configuration items..."
DEFCONFIG_FILE=./common/arch/arm64/configs/vendor/meteoric_defconfig

# Write common SUSFS/KSU configuration
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=n
CONFIG_LTO_CLANG_THIN=y
CONFIG_LTO_CLANG=y
CONFIG_OPTIMIZE_INLINING=y
CONFIG_HEADERS_INSTALL=n
EOF

# KPM configuration
if [[ "$USE_KPM" == "y" || "$USE_KPM" == "Y" ]] && [[ "$KSU_TYPE" == "sukisu" ]]; then
  echo "CONFIG_KPM=y" >> "$DEFCONFIG_FILE"
fi

# ===== Disable defconfig check =====
echo ">>> Disabling defconfig check..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== Configure ccache =====
echo ">>> Configuring ccache..."
export CCACHE_DIR="$HOME/.ccache_nothing_5.10"
export CCACHE_MAXSIZE="3G"
export CCACHE_COMPILERCHECK="none"
export CCACHE_BASEDIR="$WORKDIR"
export CCACHE_NOHASHDIR="true"
export CCACHE_HARDLINK="true"

mkdir -p "$CCACHE_DIR"
ccache -M "$CCACHE_MAXSIZE"
ccache -o compression=true
echo "sloppiness = file_stat_matches,include_file_ctime,include_file_mtime,pch_defines,file_macro,time_macros" >> "$CCACHE_DIR/ccache.conf"

echo ">>> ccache initial status:"
ccache -s

# ===== Compile kernel =====
echo ">>> Starting kernel compilation..."

# Set toolchain paths
export PATH="/usr/lib/ccache:$PATH"
export PATH="$WORKDIR/kernel_workspace/clang20/bin:$PATH"
export PATH="$WORKDIR/kernel_workspace/build-tools/bin:$PATH"

cd common

# === Real-time build (no fake timestamps) ===
BUILD_START=$(date +"%s")
echo ">>> Using real build timestamps - no fake information"

echo ">>> Generating Defconfig..."
make -j$(nproc --all) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  CC="ccache clang" LD="ld.lld" HOSTLD=ld.lld O=out \
  KCFLAGS+=-O2 KCFLAGS+=-Wno-error vendor/meteoric_defconfig

echo ">>> Compiling kernel with real timestamps (Image)..."
make -j$(nproc --all) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  CC="ccache clang" LD="ld.lld" HOSTLD=ld.lld O=out \
  KCFLAGS+=-O2 KCFLAGS+=-Wno-error \
  Image

BUILD_END=$(date +"%s")
BUILD_TIME=$((BUILD_END - BUILD_START))
echo ">>> Kernel compilation successful! Time taken: ${BUILD_TIME} seconds"

echo ">>> ccache final status:"
ccache -s

# ===== Apply KPM (if enabled) =====
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_KPM" == "y" || "$USE_KPM" == "Y" ]] && [[ "$KSU_TYPE" == "sukisu" ]]; then
  echo ">>> Using patch_linux tool to process output..."
  cd "$OUT_DIR"
  wget https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest/download/patch_linux
  chmod +x patch_linux
  ./patch_linux
  rm -f Image
  mv oImage Image
  echo ">>> KPM patch applied successfully"
else
  echo ">>> Skipping patch_linux (KPM) operation"
fi

# ===== Package AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> Cloning AnyKernel3..."
git clone https://github.com/TWO666/AnyKernel3.git -b gki-2.0 --depth=1
rm -rf ./AnyKernel3/.git

echo ">>> Copying kernel image to AnyKernel3 directory..."
if [ ! -f "$OUT_DIR/Image" ]; then
    echo "Error: Build artifact $OUT_DIR/Image not found!"
    exit 1
fi
cp "$OUT_DIR/Image" ./AnyKernel3/

echo ">>> Entering AnyKernel3 directory and packaging zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

# ===== Generate ZIP filename =====
CURRENT_TIME=$(date +'%y%m%d-%H%M%S')
ZIP_NAME="AnyKernel3_${KSU_TYPENAME}_${KSU_VERSION}_${KERNEL_VERSION}_NothingPhone2_${CURRENT_TIME}_nofake.zip"

# ===== Package ZIP file =====
echo ">>> Packaging file: $ZIP_NAME"
zip -r9 "../$ZIP_NAME" ./*

ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> Packaging completed. File location: $ZIP_PATH"

# ===== Calculate and display total time =====
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))
echo
echo "======================================"
echo ">>> Script execution completed"
echo ">>> Total time: ${MINUTES} minutes ${SECONDS} seconds"
echo "======================================"