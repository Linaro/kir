
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

get_mountpoint_dir() {
	local local_mount_point_dir="$(mktemp -p "$(pwd)" -d -t kcv_"$(date +%y%m%d_%H%M%S)"-XXXXXXXXXX)"
	echo "${local_mount_point_dir}"
}

get_new_file_name() {
	local local_rootfs_file=${1}
	local local_filename_prefix=${2}
	echo "$(find . -type f -name "${local_rootfs_file}"| awk -F'.' '{print $2}'|sed 's|/||g')${local_filename_prefix}"
}

get_new_size() {
	local local_overlay_size=${1}
	local local_rootfs_size=${2}
	local local_extra_size=${3}
	local local_not_size=
	local_new_size=$(( "${local_overlay_size}" + "${local_rootfs_size}" + "${local_extra_size}" ))
	local_new_size=$(( "${local_new_size}" / 1024 ))
	echo "${local_new_size}"
}

get_and_create_a_ddfile() {
	local local_new_file_name=${1}
	local local_new_size=${2}
	dd if=/dev/zero of="${local_new_file_name}" bs=1M count=60 seek="${local_new_size}"
	mkfs.ext4 "${local_new_file_name}"
}

get_and_create_new_rootfs() {
	local local_rootfs_file=${1}
	local local_new_file_name=${2}
	local local_new_size=${3}
	gunzip -k "${local_rootfs_file}"
	echo resize2s "${local_new_file_name}" "${local_new_size}"M
	resize2fs "${local_new_file_name}" "${local_new_size}"M
}

loopback_mount() {
	local local_new_file_name=${1}
	local local_mount_point_dir=${2}
	mount -o loop "${local_new_file_name}" "${local_mount_point_dir}"
}

loopback_unmount() {
	local local_mount_point_dir=${1}
	umount "${local_mount_point_dir}"
	rmdir "${local_mount_point_dir}"
}

create_a_sparse_xz_img() {
	local local_img_file=${1}
	local local_new_file_name=${2}
	echo "execute this command: img2simg ${local_new_file_name} ${local_img_file}"
	img2simg "${local_new_file_name}" "${local_img_file}"
	echo "execute this command: xz -c ${local_img_file} > ${local_img_file}.xz"
	xz -c "${local_img_file}" > "${local_img_file}".xz
}

create_a_ext4_xz_img() {
	local local_new_file_name=${1}
	echo "execute this command: xz -c ${local_new_file_name} > $(basename ${local_new_file_name} .ext4).ext4.xz"
	xz -c "${local_new_file_name}" > "$(basename "${local_new_file_name}" .ext4).ext4.xz"
}
