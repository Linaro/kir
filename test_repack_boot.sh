#!/bin/bash


get_artifact() {
	local local_prefix=${1}
	local local_postfix=${2}
	local artifact=$(grep ${local_prefix} index.txt|grep ${local_postfix}|tail -1|sed "s|.*${local_prefix}|${local_prefix}|"|sed "s|${local_postfix}.*|${local_postfix}|")
	echo ${artifact}
}

base=http://snapshots.linaro.org/openembedded/lkft/lkft
oe_version=sumo
machine=hikey
linux=linux-next
ROOTFS_BUILDNR=${ROOTFS_BUILDNR:-590}
BUILDNR=${ROOTFS_BUILDNR}

url="${base}"/"${oe_version}"/"${machine}"/lkft/"${linux}"/"${BUILDNR}"

# Hikey test
curl -s "${url}" -o index.txt
rootfs=$(get_artifact "rpb-console-image-lkft-" ".ext4.gz")
echo ${rootfs}
mv index.txt hikey-rootfs.index.txt
BUILDNR=latest
curl -s "${url}" -qo index.txt
modules=$(get_artifact "modules-" ".tgz")
dtb=$(get_artifact "Image-" ".dtb")
kernel=$(get_artifact "Image-" ".bin")
mv index.txt hikey-artifacts.index.txt

echo ./repack_boot.sh -t ${machine} -f "${url}"/"${rootfs}" -d "${url}"/"${dtb}" -k "${url}"/"${kernel}" -m "${url}"/"${modules}"

# am57xx-evm test
machine=am57xx-evm
BUILDNR=${ROOTFS_BUILDNR}
curl -sL "${url}" -o index.txt
rootfs=$(get_artifact "rpb-console-image-lkft-" ".ext4.gz")
mv index.txt x15-rootfs.index.txt
BUILDNR=latest
curl -sL "${url}" -qo index.txt
modules=$(get_artifact "modules-" ".tgz")
dtb=$(get_artifact "zImage-" ".dtb")
kernel=$(get_artifact "zImage-" ".bin")
echo KERNEL: ${kernel}
mv index.txt x15-artifacts.index.txt

echo ./repack_boot.sh -t ${machine} -f "${url}"/"${rootfs}" -d "${url}"/"${dtb}" -k "${url}"/"${kernel}" -m "${url}"/"${modules}"

rm *.index.txt
