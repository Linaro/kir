#!/bin/bash
# SPDX-License-Identifier: MIT

EXTRA_SIZE=${EXTRA_SIZE:-64000}
sparse_needed=0
clear_modules=0
zip_needed=0

. $(dirname $0)/libhelper

usage() {
	echo -e "$0's help text"
	echo -e "   -c, cleanup pre-installed modules in /lib/modules/"
	echo -e "      before we install the new one, default: 0"
	echo -e "   -f ROOTFS_URL, specify a url to a rootfs, either a (ext4|tar).(gz|xz)."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -o OVERLAY_URL, specify a url to a kernel module tgz file."
	echo -e "      Can be to a file on disk: file:///path/to/file.gz"
	echo -e "   -s SPARSE image or not"
	echo -e "   -z zip image or not"
	echo -e "   -h, prints out this help"
}

while getopts "cd:f:hm:o:sz" arg; do
	case $arg in
	c)
		clear_modules=1
		;;
	f)
		ROOTFS_URL="$OPTARG"
		;;
	o)
		OVERLAY_URL="$OPTARG"
		;;
	s)
		sparse_needed=1
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

if [[ -n "${OVERLAY_URL}" ]]; then
	OVERLAY_FILE=$(curl_me "${OVERLAY_URL}")
	overlay_file_type=$(file "${OVERLAY_FILE}")
	overlay_size=$(find_extracted_size "${OVERLAY_FILE}" "${overlay_file_type}")

	rootfs_file_type=$(file "${ROOTFS_FILE}")
	rootfs_size=$(find_extracted_size "${ROOTFS_FILE}" "${rootfs_file_type}")

	mount_point_dir=$(get_mountpoint_dir)

	echo ${mount_point_dir}

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

	unpack_tar_file "${OVERLAY_FILE}" "${mount_point_dir}"

	if [[ "${ROOTFS_FILE}" =~ ^.*.tar* ]]; then
		cd "${mount_point_dir}"
		tar -cJf ../"${new_file_name}".tar.xz .
		cd ..
	fi

	virt_copy_in ${new_file_name} ${mount_point_dir}
else
	new_file_name="${ROOTFS_FILE}"
fi

if [[ ${sparse_needed} -eq 1 ]]; then
	img_file="$(basename "${new_file_name}" .ext4).img"
	create_a_sparse_img "${img_file}" "${new_file_name}"
	new_file_name=${img_file}
fi

if [[ ${zip_needed} -eq 1 ]]; then
	create_a_xz_file "${new_file_name}"
fi

echo ${new_file_name}
