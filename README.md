# Description
Kernel Image Repacking (KIR) into boot images and/or rootfs' images.

# Dependencies
Dependencies on Debian or Ubuntu:

$ apt install curl img2simg mkbootimg xz-utils

# Usage
$ ./repack_boot.sh -h
$ ./resize_rootfs.sh -h

Run test_repack_boot.sh to get the cmdlines to run in order to verify that
nothing is broken.

$ ./test_repack_boot.sh
