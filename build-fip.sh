#!/bin/bash

DEVICE=myb-stm32mp257x-1GB
CROSS_COMPILE=aarch64-linux-gnu-

CURDIR=$(pwd)
ROOT_DEPLOY_DIR=${CURDIR}/output
if [ ! -d "${ROOT_DEPLOY_DIR}" ]; then
    mkdir -p ${ROOT_DEPLOY_DIR}
fi

UBOOT_BUILD_DIR=${CURDIR}/build/u-boot
OPTEE_BUILD_DIR=${CURDIR}/build/optee
TFA_BUILD_DIR=${CURDIR}/build/arm-trusted-firmware

# Compile Uboot
cd ${CURDIR}/bsp-src/st-u-boot
make ARCH=arm myd_ld25x_1G_defconfig CROSS_COMPILE=${CROSS_COMPILE} O=${UBOOT_BUILD_DIR}
make -j$(nproc) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} O=${UBOOT_BUILD_DIR}

# Compile Optee
cd ${CURDIR}/bsp-src/st-optee
make -j$(nproc) PLATFORM=stm32mp2 \
	CROSS_COMPILE_core=${CROSS_COMPILE} \
	CROSS_COMPILE_ta_arm64=${CROSS_COMPILE} \
	ARCH=arm \
	CFG_ARM64_core=y \
	NOWERROR=1 \
	CFG_TEE_CORE_LOG_LEVEL=2 \
	CFG_SCMI_SCPFW=y \
	O=${OPTEE_BUILD_DIR} \
	CFG_EMBED_DTB_SOURCE_FILE=${DEVICE}.dts \
	CFG_STM32MP25=y

# Compile TF-A
TFA_BUILD_ARGS="PLAT=stm32mp2 ARCH=aarch64 ARM_ARCH_MAJOR=8 CROSS_COMPILE=${CROSS_COMPILE} LOG_LEVEL=40 DTB_FILE_NAME=${DEVICE}.dtb SPD=opteed STM32MP25=1"

TYPE_LIST="optee-emmc optee-sdcard optee-programmer-usb optee-programmer-uart"

cd ${CURDIR}/bsp-src/st-arm-trusted-firmware

for TYPE in $TYPE_LIST; do

if [[ ${TYPE} == "optee-emmc" ]]; then
	TYPE_ARG="STM32MP_EMMC=1"
elif [[ ${TYPE} == "optee-sdcard" ]]; then
	TYPE_ARG="STM32MP_SDMMC=1"
elif [[ ${TYPE} == "optee-programmer-usb" ]]; then
	TYPE_ARG="STM32MP_USB_PROGRAMMER=1"
elif [[ ${TYPE} == "optee-programmer-uart" ]]; then
	TYPE_ARG="STM32MP_UART_PROGRAMMER=1"
fi

echo "==== build for ${TYPE}, arg is ${TYPE_ARG} ===="

make -j$(nproc) ${TFA_BUILD_ARGS} BUILD_PLAT=${TFA_BUILD_DIR}/${TYPE}-${DEVICE} \
	${TYPE_ARG} dtbs
make -j$(nproc) ${TFA_BUILD_ARGS} BUILD_PLAT=${TFA_BUILD_DIR}/${TYPE}-${DEVICE} \
	${TYPE_ARG} STM32MP_LPDDR4_TYPE=1 all
make -j$(nproc) ${TFA_BUILD_ARGS} BUILD_PLAT=${TFA_BUILD_DIR}/${TYPE}-${DEVICE} \
	BL32=${OPTEE_BUILD_DIR}/core/tee-header_v2.bin \
	BL32_EXTRA1=${OPTEE_BUILD_DIR}/core/tee-pager_v2.bin \
	BL33=${UBOOT_BUILD_DIR}/u-boot-nodtb.bin \
	BL33_CFG=${UBOOT_BUILD_DIR}/u-boot.dtb \
	DTB_FILE_NAME=${DEVICE}.dtb \
	${TYPE_ARG} STM32MP_LPDDR4_TYPE=1 all fip

cp ${TFA_BUILD_DIR}/${TYPE}-${DEVICE}/tf-a-${DEVICE}.stm32 ${ROOT_DEPLOY_DIR}/tf-a-${DEVICE}-${TYPE}.stm32
cp ${TFA_BUILD_DIR}/${TYPE}-${DEVICE}/fip.bin ${ROOT_DEPLOY_DIR}/fip-${DEVICE}-${TYPE}.bin

done

echo "Done."

exit 0


