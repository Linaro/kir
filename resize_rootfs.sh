#!/bin/bash

#set -xe

# ./resize_rootfs.sh <rootfs> <modules>
#
# Dependencies on Debian sid or Ubuntu 18.04:
# apt install xz-utils img2simg curl

LXC_ROOTFS_FILE=${1}
OVERLAY_FILE=${2:-/lava-lxc/overlays/target/overlay.tar.gz}
EXTRA_SIZE=${EXTRA_SIZE:-512000}
SPARSE_NEEDED=${3:-no}

. $(dirname $0)/helper.sh

if [[ -d /lava-lxc ]]; then
	cd /lava-lxc
else
	mkdir -p $(pwd)/lava-lxc
	cd $(pwd)/lava-lxc
fi

OVERLAY_FILE=$(curl_me "${OVERLAY_FILE}")
LXC_ROOTFS_FILE=$(curl_me "${LXC_ROOTFS_FILE}")

overlay_file_type=$(file "${OVERLAY_FILE}")
rootfs_file_type=$(file "${LXC_ROOTFS_FILE}")
overlay_size=$(find_extracted_size "${OVERLAY_FILE}" "${overlay_file_type}")
rootfs_size=$(find_extracted_size "${LXC_ROOTFS_FILE}" "${rootfs_file_type}")

mount_point_dir=$(mktemp -p $(pwd) -d -t kcv_$(date +%y%m%d_%H%M%S)-XXXXXXXXXX)

echo ${mount_point_dir}

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

unpack_tar_file "${OVERLAY_FILE}" "${mount_point_dir}"

if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
	cd "${mount_point_dir}"
	tar -cJf ../"${new_file_name}".tar.xz .
	cd ..
fi

loopback_unmount "${mount_point_dir}"

if [[ ${SPARSE_NEEDED} == "yes" ]]; then
	img_file="$(basename "${new_file_name}" .ext4).img"
	create_a_sparse_xz_img "${img_file}" "${new_file_name}"
else
	create_a_ext4_xz_img "${new_file_name}"
fi

echo ${new_file_name}
