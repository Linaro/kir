#!/bin/bash

#set -xe

. $(dirname $0)/helper.sh

if [[ -d /lava-lxc ]]; then
	cd /lava-lxc
else
	mkdir -p $(pwd)/lava-lxc
	cd $(pwd)/lava-lxc
fi

clear_modules=0
EXTRA_SIZE=${EXTRA_SIZE:-64000}

usage() {
	echo -e "$0's help text"
	echo -e "   -c, cleanup pre-installed modules in /lib/modules/"
	echo -e "      before we install the new one, default: 0"
	echo -e "   -d DTB_URL, specify a url to a device tree blob file."
	echo -e "      Can be to a file on disk: file:///path/to/file.dtb"
	echo -e "   -f ROOTFS_URL, specify a url to a rootfs, either a (ext4|tar).(gz|xz)."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -k KERNEL_URL, specify a url to a kernel zImage or Image.gz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -m MODULE_URL, specify a url to a kernel module tgz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -t TARGET, add machine name"
	echo -e "   -h, prints out this help"
}

while getopts "cd:f:hk:m:t:" arg; do
	case $arg in
	c)
		clear_modules=1
		;;
	d)
		LXC_DTB_URL="$OPTARG"
		;;
	f)
		LXC_ROOTFS_URL="$OPTARG"
		;;
	k)
		LXC_KERNEL_URL="$OPTARG"
		;;
	m)
		LXC_MODULES_URL="$OPTARG"
		;;
	t)
		TARGET="$OPTARG"
		;;
	h|*)
		usage
		exit 0
		;;
	esac
done


LXC_ROOTFS_FILE=$(curl_me "${LXC_ROOTFS_URL}")
LXC_MODULES_FILE=$(curl_me "${LXC_MODULES_URL}")
LXC_KERNEL_FILE=$(curl_me "${LXC_KERNEL_URL}")
LXC_DTB_FILE=$(curl_me "${LXC_DTB_URL}")

kernel_file_type=$(file "${LXC_KERNEL_FILE}")
dtb_file_type=$(file "${LXC_DTB_FILE}")

if [[ ${dtb_file_type} =~ *"Device Tree Blob"* ]]; then
	echo "Need to pass in a dtb file"
	exit 1
fi

case ${TARGET} in
	am57xx-evm)
	;;
	dragonboard-410c)
	if [[ ${kernel_file_type} =~ *"gzip compressed data"* ]]; then
		echo "Need to pass in a zImage file"
		exit 1
	fi

	cat "${LXC_KERNEL_FILE}" "${LXC_DTB_FILE}" > zImage+dtb
	echo "This is not an initrd">initrd.img

	new_file_name="$(find . -type f -name "${LXC_KERNEL_FILE}"| awk -F'.' '{print $2}'|sed 's|/||g')"
	mkbootimg --kernel zImage+dtb --ramdisk initrd.img --pagesize 2048 --base 0x80000000 --cmdline "root=/dev/mmcblk0p10 rw rootwait console=ttyMSM0,115200n8" --output boot-"${new_file_name}".img
	;;
	hikey)
	modules_file_type=$(file "${LXC_MODULES_FILE}")
	rootfs_file_type=$(file "${LXC_ROOTFS_FILE}")
	modules_size=$(find_extracted_size "${LXC_MODULES_FILE}" "${modules_file_type}")
	rootfs_size=$(find_extracted_size "${LXC_ROOTFS_FILE}" "${rootfs_file_type}")
	mount_point_dir=$(get_mountpoint_dir)
	new_file_name=$(get_new_file_name "${LXC_ROOTFS_FILE}" ".new.rootfs")
	new_size=$(get_new_size "${overlay_size}" "${rootfs_size}" "${EXTRA_SIZE}")
	if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
		get_and_create_a_ddfile "${new_file_name}" "${new_size}"
	else
		new_file_name=$(basename "${LXC_ROOTFS_FILE}" .gz)
		get_and_create_new_rootfs "${new_file_name}" "${new_file_name}" "${new_size}"
	fi

	loopback_mount "${new_file_name}" "${mount_point_dir}"
	if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
		unpack_tar_file "${LXC_ROOTFS_FILE}" "${mount_point_dir}"
	fi

	if [[ $clear_modules -eq 1 ]]; then
		rm -rf "${mount_point_dir}"/lib/modules/*
	fi
	unpack_tar_file "${LXC_MODULES_FILE}" "${mount_point_dir}"

	cp "${LXC_DTB_FILE}" "${mount_point_dir}"/boot/
	cp "${LXC_KERNEL_FILE}" "${mount_point_dir}"/boot/
	cd "${mount_point_dir}"/boot
	cp hi6220-hikey.dtb hi6220-hikey.dtb.bak
	ln -sf "${LXC_DTB_FILE}" hi6220-hikey.dtb
	ln -sf "${LXC_KERNEL_FILE}" Image
	cd -

	loopback_unmount "${mount_point_dir}"
	img_file="$(basename "${new_file_name}" .ext4).img"
	create_a_sparse_xz_img "${img_file}" "${new_file_name}"
	;;
	intel-corei7-64)
	;;
	intel-core2-32)
	;;
	*)
	usage
	exit 1
	;;
esac
