#!/bin/bash


get_artifact() {
	local local_prefix=${1}
	local local_postfix=${2}
	local artifact=$(grep ${local_prefix} index.txt|grep ${local_postfix}|tail -1|sed "s|.*${local_prefix}|${local_prefix}|"|sed "s|${local_postfix}.*|${local_postfix}|")
	echo ${artifact}
}

base="http://snapshots.linaro.org/openembedded/lkft/lkft"
oe_version="sumo"
linux="linux-mainline"
ROOTFS_BUILDNR="2140"


# Hikey test
machine=hikey
BUILDNR=${ROOTFS_BUILDNR}
url="${base}"/"${oe_version}"/"${machine}"/lkft/"${linux}"/"${BUILDNR}"
curl -sL "${url}" -o index.txt
rootfs="${url}/$(get_artifact "rpb-console-image-lkft-" ".ext4.gz")"
mv index.txt hikey-rootfs.index.txt
BUILDNR=latest
url="${base}"/"${oe_version}"/"${machine}"/lkft/"${linux}"/"${BUILDNR}"
curl -sL "${url}" -o index.txt
modules="${url}/$(get_artifact "modules-" ".tgz")"
dtb="${url}/$(get_artifact "Image-" ".dtb")"
kernel="${url}/$(get_artifact "Image-" ".bin")"
mv index.txt hikey-artifacts.index.txt

echo
echo TARGET: ${machine}
echo ./repack_boot.sh -t ${machine} -f "${rootfs}" -d "${dtb}" -k "${kernel}" -m "${modules}"

# am57xx-evm test
machine=am57xx-evm
BUILDNR="${ROOTFS_BUILDNR}"
url="${base}"/"${oe_version}"/"${machine}"/lkft/"${linux}"/"${BUILDNR}"
curl -sL "${url}" -o index.txt
rootfs="${url}/$(get_artifact "rpb-console-image-lkft-" ".ext4.gz")"
mv index.txt x15-rootfs.index.txt
BUILDNR="latest"
url="${base}"/"${oe_version}"/"${machine}"/lkft/"${linux}"/"${BUILDNR}"
curl -sL "${url}" -qo index.txt
modules="${url}/$(get_artifact "modules-" ".tgz")"
dtb="${url}/$(get_artifact "zImage-" ".dtb")"
kernel="${url}/$(get_artifact "zImage-" ".bin")"
mv index.txt x15-artifacts.index.txt

echo
echo TARGET: ${machine}
echo ./repack_boot.sh -t ${machine} -f "${rootfs}" -d "${dtb}" -k "${kernel}" -m "${modules}"

rm *.index.txt
