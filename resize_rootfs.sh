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

find_extracted_size() {
	local local_file=${1}
	local local_file_type=${2}
	local local_size=
	if [[ ${local_file_type} = *"POSIX tar archive"* ]]; then
		local_size=$(ls -l "${local_file}" | awk '{print $5}')
		local_size=$(( "${local_size}" / 1024 ))
	elif [[ ${local_file_type} = *"gzip compressed data"* ]]; then
		local_size=$(gzip -l "${local_file}" | tail -1 | awk '{print $2}')
		local_size=$(( "${local_size}" / 1024 ))
	elif [[ ${local_file_type} = *"XZ compressed data"* ]]; then
		local_size=$(xz -l "${local_file}" | tail -1 | awk '{print $5}'|sed 's/,//g' | awk -F'.' '{print $1}')
		local_size=$(( "${local_size}"+1 ))
		local_size=$(( "${local_size}" * 1024 ))
	elif [[ ${local_file_type} = *"ext4 filesystem data"* ]]; then
		local_size=$(ls -l "${local_file}" | awk '{print $5}')
		local_size=$(( "${local_size}" / 1024 ))
	else
		echo "ABORT: Format not supported: ${local_size}"
		exit 1
	fi
	echo ${local_size}
}

unpack_tar_file() {
	local local_file=${1}
	local local_mount_point=${2}
	tar -xvf ${local_file} -C ${local_mount_point}
}

curl_me() {
	local local_file=${1}
	if [[ ! -f $(basename "${local_file}") ]]; then
		curl -sSL -o "$(basename "${local_file}")" "${local_file}"
		retcode=$?
		if [[ ${retcode} -ne 0 ]]; then
			exit ${retconde}
		fi
	fi
	echo $(basename "${local_file}")
}

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

new_file_name="$(find . -type f -name "${LXC_ROOTFS_FILE}"| awk -F'.' '{print $2}'|sed 's|/||g').new.rootfs"
new_size=$(( "${overlay_size}" + "${rootfs_size}" + "${EXTRA_SIZE}" ))
new_size=$(( "${new_size}" / 1024 ))


if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
	dd if=/dev/zero of="${new_file_name}" bs=1M count=60 seek="${new_size}"
	mkfs.ext4 "${new_file_name}"
else
	new_file_name=$(basename "${LXC_ROOTFS_FILE}" .gz)
	gunzip -k "${LXC_ROOTFS_FILE}"
	fsck_code=$(e2fsck -y -f "${new_file_name}")
	resize2fs "${new_file_name}" "${new_size}"K
fi
mount -o loop "${new_file_name}" "${mount_point_dir}"
if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
	unpack_tar_file "${LXC_ROOTFS_FILE}" "${mount_point_dir}"
fi

unpack_tar_file "${OVERLAY_FILE}" "${mount_point_dir}"

if [[ "${LXC_ROOTFS_FILE}" =~ ^.*.tar* ]]; then
	cd "${mount_point_dir}"
	tar -cJf ../"${new_file_name}".tar.xz .
	cd ..
fi
umount "${mount_point_dir}"
rmdir "${mount_point_dir}"

if [[ ${SPARSE_NEEDED} == "yes" ]]; then
	img_file="$(basename "${new_file_name}" .ext4).img"
	echo "execute this command: img2simg ${new_file_name} ${img_file}"
	img2simg "${new_file_name}" "${img_file}"
	echo "execute this command: xz -c ${img_file} > ${img_file}.xz"
	xz -c "${img_file}" > "${img_file}".xz
else
	echo "execute this command: xz -c ${new_file_name} > $(basename ${new_file_name} .ext4).ext4.xz"
	xz -c "${new_file_name}" > "$(basename "${new_file_name}" .ext4).ext4.xz"
fi

echo ${new_file_name}
