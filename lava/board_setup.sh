#!/bin/bash
# SPDX-License-Identifier: MIT

set -e
#set -xe

DEVICE_TYPE=${1}
ROOTFS_STRING=${2:-"image-"}
kir=$(dirname $0)/..

echo "PRINTOUT"
local_initrd=$(find . -type f -name '*initramfs*')
echo "PRINTOUT initramfs: ${local_initrd}"
local_modules=$(find . -type f -name '*modules*')
echo "PRINTOUT MODULES: ${local_modules}"
file ${local_modules}
local_kernel=$(find . -type f -name '*Image*' | grep -vi dtb)
echo "PRINTOUT KERNEL: ${local_kernel}"
file ${local_kernel}
local_rootfs=$(find . -type f -name "*${ROOTFS_STRING}*.ext4*")||true
if [[ -z ${local_rootfs} ]]; then
	local_rootfs=$(find . -type f -name "*${ROOTFS_STRING}*.tar*")
fi
echo "PRINTOUT ROOTFS: ${local_rootfs}"
file ${local_rootfs}

case ${DEVICE_TYPE} in
	x15)
		local_dtb=$(find . -type f -name '*.dtb')
		echo "PRINTOUT DTB: ${local_dtb}"
		file ${local_dtb}
		machine=am57xx-evm
		${kir}/repack_boot.sh -t "${machine}" -f "${local_rootfs}" -d "${local_dtb}" -k "${local_kernel}" -m "${local_modules}"
		;;
	dragonboard-410c|dragonboard-845c|e850-96|qrb5165-rb5)
		local_dtb=$(find . -type f -name '*.dtb')
		echo "PRINTOUT DTB: ${local_dtb}"
		file ${local_dtb}
		machine=${DEVICE_TYPE}
		case ${DEVICE_TYPE} in
			dragonboard-410c|dragonboard-845c|qrb5165-rb5)
				${kir}/repack_boot.sh -t "${machine}" -d "${local_dtb}" -k "${local_kernel}" -m "${local_modules}" -i "${local_initrd}"
				${kir}/resize_rootfs.sh -s -f "${local_rootfs}"
				;;
			*)
				${kir}/repack_boot.sh -t "${machine}" -d "${local_dtb}" -k "${local_kernel}"
				${kir}/resize_rootfs.sh -s -f "${local_rootfs}" -o "${local_modules}"
				;;
		esac
		;;
	nfs-dragonboard-845c)

		local_dtb=$(find . -type f -name '*.dtb')
		echo "PRINTOUT DTB: ${local_dtb}"
		file ${local_dtb}
		machine=dragonboard-845c
		${kir}/repack_boot.sh -t "${machine}" -d "${local_dtb}" -k "${local_kernel}" "-n"
		;;
	hi6220-hikey|hi6220-hikey-r2)
		local_ptable=$(find . -type f -name '*ptable*-8g.img')
		echo "PRINTOUT ptable: ${local_ptable}"
		file ${local_ptable}
		local_boot=$(find . -type f -name 'boot*.uefi.img')
		mv ${local_boot} boot.img
		local_boot=boot.img
		echo "PRINTOUT boot: ${local_boot}"
		file ${local_boot}
		local_dtb=$(find . -type f -name '*.dtb')
		echo "PRINTOUT DTB: ${local_dtb}"
		file ${local_dtb}
		machine=hikey
		${kir}/repack_boot.sh -t "${machine}" -f "${local_rootfs}" -d "${local_dtb}" -k "${local_kernel}" -m "${local_modules}"
		;;
	*)
		usage
		exit 1
		;;
esac

ls
pwd
local_rootfs_img=$(find . -type f -name "*${ROOTFS_STRING}*.img")
if [ -n "${local_rootfs_img}" ] && [ "${local_rootfs_img}" != "./rootfs.img" ]; then
	mv ${local_rootfs_img} rootfs.img
	ls -l
	pwd
	file rootfs.img
fi
