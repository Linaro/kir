#!/usr/bin/env python3

import argparse
import logging
import os
import re
import requests
import simplediskimage

logging.basicConfig(level=logging.DEBUG)

def get_file(path):
    if re.search(r'https?://', path):
        request = requests.get(path, allow_redirects=True)
        request.raise_for_status()
        filename = path.split('/')[-1]
        with open(filename, 'wb') as f:
            f.write(request.content)
        return filename
    elif os.path.exists(path):
        return path
    else:
        raise Exception(f"Path {path} not found")

def main(args):
    mlo = get_file(args.get('mlo', None))
    uboot = get_file(args.get('uboot', None))
    output_file = args.get('output_file', None)
    image = simplediskimage.DiskImage(output_file, partition_table='msdos',
                                partitioner=simplediskimage.Sfdisk)
    pf = image.new_partition("fat16", partition_flags=["BOOT"])
    pf.copy(uboot)
    pf.copy(mlo)
    #pf.set_extra_bytes(45 * diskimage.SI.Mi)
    pf.set_fixed_size_bytes(48272 * simplediskimage.SI.ki)

    image.commit()
    print("sudo kpartx -av " + output_file)
    print("...")
    print("sudo kpartx -dv " + output_file)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--mlo", required=True,
                        help="url or path to MLO file")
    parser.add_argument("--uboot", required=True,
                        help="url or path to u-boot.img file")
    parser.add_argument("--output_file", required=True,
                        help="name the newly created .img file")
    args = vars(parser.parse_args())
    if args:
        main(args)
    else:
        exit(1)
