#!/bin/bash
# SPDX-License-Identifier: MIT

. $(dirname $0)/libhelper

clear_modules=0
zip_needed=0
nfsrootfs=0
EXTRA_SIZE=${EXTRA_SIZE:-64000}

usage() {
	echo -e "$0's help text"
	echo -e "   -c, cleanup pre-installed modules in /lib/modules/"
	echo -e "      before we install the new one, default: 0"
	echo -e "   -d DTB_URL, specify a url to a device tree blob file."
	echo -e "      Can be to a file on disk: file:///path/to/file.dtb"
	echo -e "   -f ROOTFS_URL, specify a url to a rootfs, either a (ext4|tar).(gz|xz)."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -i INITRD_URL, specify a url to an initrd.cpio.gz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -k KERNEL_URL, specify a url to a kernel zImage or Image.gz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -m MODULE_URL, specify a url to a kernel module tgz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -t TARGET, add machine name"
	echo -e "   -z zip image or not"
	echo -e "   -h, prints out this help"
}

while getopts "cd:f:hi:k:m:nt:z" arg; do
	case $arg in
	c)
		clear_modules=1
		;;
	d)
		DTB_URL="$OPTARG"
		;;
	f)
		ROOTFS_URL="$OPTARG"
		;;
	i)
		INITRD_URL="$OPTARG"
		;;
	k)
		KERNEL_URL="$OPTARG"
		;;
	m)
		MODULES_URL="$OPTARG"
		;;
	n)
		nfsrootfs=1
		;;
	t)
		TARGET="$OPTARG"
		;;
	z)
		zip_needed=1
		;;
	h|*)
		usage
		exit 0
		;;
	esac
done


ROOTFS_FILE=$(curl_me "${ROOTFS_URL}")
INITRD_FILE=$(curl_me "${INITRD_URL}")
MODULES_FILE=$(curl_me "${MODULES_URL}")
KERNEL_FILE=$(curl_me "${KERNEL_URL}")
DTB_FILE=$(curl_me "${DTB_URL}")

kernel_file_type=$(file "${KERNEL_FILE}")
dtb_file_type=$(file "${DTB_FILE}")

if [[ ${dtb_file_type} =~ *"Device Tree Blob"* ]]; then
	echo "Need to pass in a dtb file"
	exit 1
fi

case ${TARGET} in
	e850-96)
		if [[ ${kernel_file_type} = *"gzip compressed data"* ]]; then
			gunzip ${KERNEL_FILE}
			KERNEL_FILE=$(echo "${KERNEL_FILE}" | cut -d'.' -f1)
		fi
		cmdline="rw androidboot.hardware=exynos850 androidboot.selinux=permissive buildvariant=eng"
		mkbootimg --kernel "${KERNEL_FILE}" --cmdline "${cmdline}" --os_version 10 --os_patch_level 2019-12-01 --tags_offset 0 --header_version 2 --dtb "${DTB_FILE}" --dtb_offset 0 --output boot.img
		file boot.img
		;;
	dragonboard-410c|dragonboard-845c|qrb5165-rb5)
		if [[ ! ${kernel_file_type} = *"gzip compressed data"* ]]; then
			echo "Need to pass in a zImage file."
			echo "gzip -c Image > zImage"
			gzip -c Image > zImage
			KERNEL_FILE=zImage
		fi

		cat "${KERNEL_FILE}" "${DTB_FILE}" > zImage+dtb
		mkdir -p modules_dir/usr
		unpack_tar_file "${MODULES_FILE}" modules_dir/usr
		cd modules_dir
		find . | cpio -o -H newc -R +0:+0 | gzip -9 > ../modules.cpio.gz
		cd -
		initrd_filename="initrd.cpio.gz"
		cat "${INITRD_FILE}" modules.cpio.gz > "${initrd_filename}"


		# NFS_SERVER_IP and NFS_ROOTFS exported from the environment.
		echo ${NFS_SERVER_IP} and ${NFS_ROOTFS}
		nfscmdline="root=/dev/nfs nfsroot=$NFS_SERVER_IP:$NFS_ROOTFS,nfsvers=3 ip=dhcp"
		console_cmdline="console=tty0 console=ttyMSM0,115200n8"
		cmdline_extra="copy_modules"

		case ${TARGET} in
			dragonboard-410c)
				cmdline="root=/dev/mmcblk0p14 rw rootwait ${console_cmdline} ${cmdline_extra}"
				pagasize=2048
				;;
			dragonboard-845c)
				cmdline_extra="${cmdline_extra} clk_ignore_unused pd_ignore_unused"
				cmdline="root=/dev/sda1 init=/sbin/init rw ${console_cmdline} ${cmdline_extra} -- "
				pagasize=4096
				;;
			qrb5165-rb5)
				cmdline="root=PARTLABEL=rootfs rw rootwait earlycon debug ${console_cmdline} ${cmdline_extra}"
				pagasize=4096
				;;
		esac

		if [[ ${nfsrootfs} == 1 ]]; then
			cmdline="${nfscmdline} ${console_cmdline} ${cmdline_extra}"
		fi

		new_file_name="$(find . -type f -name "${KERNEL_FILE}"| awk -F'.' '{print $2}'|sed 's|/||g')"
		mkbootimg --kernel zImage+dtb --ramdisk "${initrd_filename}" --pagesize "${pagasize}" --base 0x80000000 --cmdline "${cmdline}" --output boot.img
		file boot.img
		;;
	am57xx-evm|hikey)
		modules_file_type=$(file "${MODULES_FILE}")
		rootfs_file_type=$(file "${ROOTFS_FILE}")
		modules_size=$(find_extracted_size "${MODULES_FILE}" "${modules_file_type}")
		rootfs_size=$(find_extracted_size "${ROOTFS_FILE}" "${rootfs_file_type}")
		mount_point_dir=$(get_mountpoint_dir)
		new_file_name=$(get_new_file_name "${ROOTFS_FILE}" ".new.rootfs")
		new_size=$(get_new_size "${overlay_size}" "${rootfs_size}" "${EXTRA_SIZE}")
		if [[ "${ROOTFS_FILE}" =~ ^.*.tar* ]]; then
			get_and_create_a_ddfile "${new_file_name}" "${new_size}"
		else
			new_file_name=$(basename "${ROOTFS_FILE}" .gz)
			get_and_create_new_rootfs "${ROOTFS_FILE}" "${new_file_name}" "${new_size}"
		fi

		if [[ "${ROOTFS_FILE}" =~ ^.*.tar* ]]; then
			unpack_tar_file "${ROOTFS_FILE}" "${mount_point_dir}"
		fi

		if [[ $clear_modules -eq 1 ]]; then
			rm -rf "${mount_point_dir}"/lib/modules/*
		fi
		unpack_tar_file "${MODULES_FILE}" "${mount_point_dir}"

		mkdir -p "${mount_point_dir}"/boot
		cp "${DTB_FILE}" "${mount_point_dir}"/boot/
		cp "${KERNEL_FILE}" "${mount_point_dir}"/boot/
		cd "${mount_point_dir}"/boot

		if [[ ${TARGET} = *"hikey"* ]]; then
			dtb_file="hi6220-hikey.dtb"
			kernel_image="Image"
		else
			dtb_file="am57xx-beagle-x15.dtb"
			kernel_image="zImage"
		fi

		if [[ "${DTB_FILE}" != "${dtb_file}" ]]; then
			ln -sf "${DTB_FILE}" "${dtb_file}"
		fi
		if [[ "${KERNEL_FILE}" != "${kernel_image}" ]]; then
			ln -sf "${KERNEL_FILE}" "${kernel_image}"
		fi
		cd -

		virt_copy_in ${new_file_name} ${mount_point_dir}
		img_file="$(basename "${new_file_name}" .ext4).img"
		create_a_sparse_img "${img_file}" "${new_file_name}"
		;;
	*)
		usage
		exit 1
		;;
esac
