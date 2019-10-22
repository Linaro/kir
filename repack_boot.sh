#!/bin/bash

# ./repack_boot.sh <zImage> <dtb>
#
# Dependencies on Debian sid or Ubuntu 18.04:
# apt install mkbootimg

LXC_KERNEL_FILE=${1}
LXC_DTB_FILE=${1}


if [[ -d /lava-lxc ]]; then
	cd /lava-lxc
else
	mkdir -p $(pwd)/lava-lxc
	cd $(pwd)/lava-lxc
fi

if [[ ! $(echo ${LXC_KERNEL_FILE} |grep "gzip compressed data") ]];
	echo "Need to pass in a zImage file"
fi

if [[ ! $(echo ${LXC_DTB_FILE} |grep "Device Tree Blob") ]];
	echo "Need to pass in a dtb file"
fi

cat ${LXC_KERNEL_FILE} ${LXC_DTB_FILE} > zImage+dtb
echo "This is not an initrd">initrd.img

new_file_name=$(ls ${LXC_KERNEL_FILE}| awk -F'.' '{print $1}')
mkbootimg --kernel zImage+dtb --ramdisk initrd.img --pagesize 2048 --base 0x80000000 --cmdline "root=/dev/mmcblk0p10 rw rootwait console=ttyMSM0,115200n8" --output boot-${new_file_name}.img
