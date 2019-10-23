
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
