#!/bin/bash

#set -xe

# ./repack_boot.sh <zImage> <dtb>
#
# Dependencies on Debian sid or Ubuntu 18.04:
# apt install mkbootimg curl

LXC_KERNEL_FILE=${1}
LXC_DTB_FILE=${2}

. $(dirname $0)/helper.sh

if [[ -d /lava-lxc ]]; then
	cd /lava-lxc
else
	mkdir -p $(pwd)/lava-lxc
	cd $(pwd)/lava-lxc
fi

LXC_KERNEL_FILE=$(curl_me "${LXC_KERNEL_FILE}")
LXC_DTB_FILE=$(curl_me "${LXC_DTB_FILE}")

kernel_file_type=$(file "${LXC_KERNEL_FILE}")
dtb_file_type=$(file "${LXC_DTB_FILE}")

if [[ ${kernel_file_type} =~ *"gzip compressed data"* ]]; then
	echo "Need to pass in a zImage file"
	exit 1
fi

if [[ ${dtb_file_type} =~ *"Device Tree Blob"* ]]; then
	echo "Need to pass in a dtb file"
	exit 1
fi

cat "${LXC_KERNEL_FILE}" "${LXC_DTB_FILE}" > zImage+dtb
echo "This is not an initrd">initrd.img

new_file_name="$(find . -type f -name "${LXC_KERNEL_FILE}"| awk -F'.' '{print $2}'|sed 's|/||g')"
mkbootimg --kernel zImage+dtb --ramdisk initrd.img --pagesize 2048 --base 0x80000000 --cmdline "root=/dev/mmcblk0p10 rw rootwait console=ttyMSM0,115200n8" --output boot-"${new_file_name}".img
