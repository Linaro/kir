# Description
Kernel Image Repacking (KIR) into boot images and/or rootfs' images.

# Dependencies
Dependencies on Debian sid or Ubuntu 18.04:

$ apt install curl img2simg mkbootimg xz-utils

# Usage
$ ./repack_boot.sh -h

Run test_repack_boot.sh to get the cmdlines to run in order to verify that
nothing is broken.

$ ./test_repack_boot.sh
