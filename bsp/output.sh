#!/bin/bash

START_TIME=${SECONDS}

print_elapsed_time()
{
    local elapsed_time=$((SECONDS - START_TIME))
    local hour=$((elapsed_time / 3600))
    local minute=$(((elapsed_time % 3600) / 60))
    local second=$((elapsed_time % 60))

    echo
    echo "========================================"
    printf " 전체 실행 시간: %02d:%02d:%02d\n" \
        "${hour}" "${minute}" "${second}"
    echo "========================================"
}

trap print_elapsed_time EXIT

set -euo pipefail

# 이 스크립트가 위치한 최상위 프로젝트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 출력 폴더
OUTPUT_DIR="${SCRIPT_DIR}/output"

# 복사할 바이너리 경로
UBOOT_IMAGE="${SCRIPT_DIR}/uboot/u-boot-sunxi-with-spl.bin"

KERNEL_IMAGE="${SCRIPT_DIR}/kernel/build/arch/arm/boot/zImage"
KERNEL_DTB="${SCRIPT_DIR}/kernel/build/arch/arm/boot/dts/allwinner/hg-t113s3-kit-linux.dtb"

ROOTFS_IMAGE="${SCRIPT_DIR}/rootfs/buildroot-2026.05/output/images/rootfs.squashfs"


#
# 전체 프로젝트 빌드
#

JOBS="${JOBS:-$(nproc)}"

ARCH="arm"
CROSS_COMPILE="arm-linux-gnueabihf-"

UBOOT_DIR="${SCRIPT_DIR}/uboot"

KERNEL_DIR="${SCRIPT_DIR}/kernel/linux-6.18.36"
KERNEL_BUILD_DIR="${SCRIPT_DIR}/kernel/build"

BUILDROOT_DIR="${SCRIPT_DIR}/rootfs/buildroot-2026.05"


#
# 실제 사용하는 defconfig 이름으로 수정
#
UBOOT_DEFCONFIG="hg-t113s3-kit-spi_defconfig"
KERNEL_DEFCONFIG="hg-t113s3-kit-linux_defconfig"
BUILDROOT_DEFCONFIG="${BUILDROOT_DIR}/configs/hg-t113s3-kit-rootfs_defconfig"


echo "========================================"
echo " 전체 프로젝트 빌드 시작"
echo " 병렬 작업 수: ${JOBS}"
echo "========================================"


#
# U-Boot 빌드
#

echo
echo "========================================"
echo " U-Boot 빌드"
echo "========================================"

if [ ! -d "${UBOOT_DIR}" ]; then
    echo "[ERROR] U-Boot 경로가 없습니다."
    echo "경로: ${UBOOT_DIR}"
    exit 1
fi

make -C "${UBOOT_DIR}" \
    ARCH="${ARCH}" \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    "${UBOOT_DEFCONFIG}"

make -C "${UBOOT_DIR}" \
    ARCH="${ARCH}" \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    -j"${JOBS}"


#
# Linux Kernel 빌드
#

echo
echo "========================================"
echo " Linux Kernel 빌드"
echo "========================================"

if [ ! -d "${KERNEL_DIR}" ]; then
    echo "[ERROR] Kernel 소스 경로가 없습니다."
    echo "경로: ${KERNEL_DIR}"
    exit 1
fi

make -C "${KERNEL_DIR}" \
    O="${KERNEL_BUILD_DIR}" \
    ARCH="${ARCH}" \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    "${KERNEL_DEFCONFIG}"

make -C "${KERNEL_DIR}" \
    O="${KERNEL_BUILD_DIR}" \
    ARCH="${ARCH}" \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    -j"${JOBS}" \
    zImage allwinner/hg-t113s3-kit-linux.dtb modules

#
# Buildroot 빌드
#

echo
echo "========================================"
echo " Buildroot 빌드"
echo "========================================"

if [ ! -d "${BUILDROOT_DIR}" ]; then
    echo "[ERROR] Buildroot 경로가 없습니다."
    echo "경로: ${BUILDROOT_DIR}"
    exit 1
fi

if [ ! -f "${BUILDROOT_DEFCONFIG}" ]; then
    echo "[ERROR] Buildroot defconfig 파일이 없습니다."
    echo "경로: ${BUILDROOT_DEFCONFIG}"
    exit 1
fi

make -C "${BUILDROOT_DIR}" BR2_DEFCONFIG="${BUILDROOT_DEFCONFIG}" defconfig
make -C "${BUILDROOT_DIR}"

echo
echo "========================================"
echo " 전체 프로젝트 빌드 완료"
echo "========================================"
echo 
echo "========================================"
echo " 바이너리 통합 시작"
echo "========================================"

# output 폴더가 없으면 생성
mkdir -p "${OUTPUT_DIR}"


copy_image()
{
    local source_file="$1"

	if [ ! -f "${source_file}" ]; then
		echo "[ERROR] 파일을 찾을 수 없습니다."
		echo "경로: ${source_file}"
		exit 1
	fi

    cp -f "${source_file}" "${OUTPUT_DIR}/"
    echo "[COPY] $(basename "${source_file}")"
}

copy_image "${UBOOT_IMAGE}"
copy_image "${KERNEL_IMAGE}"
copy_image "${KERNEL_DTB}"
copy_image "${ROOTFS_IMAGE}"

echo
echo "========================================"
echo " 바이너리 통합 완료"
echo "========================================"
echo "출력 경로: ${OUTPUT_DIR}"
echo

ls -lh \
    "${OUTPUT_DIR}/u-boot-sunxi-with-spl.bin" \
    "${OUTPUT_DIR}/zImage" \
    "${OUTPUT_DIR}/hg-t113s3-kit-linux.dtb" \
    "${OUTPUT_DIR}/rootfs.squashfs"

ELAPSED_TIME=$((SECONDS - START_TIME))

ELAPSED_HOUR=$((ELAPSED_TIME / 3600))
ELAPSED_MIN=$(((ELAPSED_TIME % 3600) / 60))
ELAPSED_SEC=$((ELAPSED_TIME % 60))

echo
echo "========================================"
printf " 전체 실행 시간: %02d:%02d:%02d\n" \
    "${ELAPSED_HOUR}" \
    "${ELAPSED_MIN}" \
    "${ELAPSED_SEC}"
echo "========================================"
