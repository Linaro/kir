#!/usr/bin/env python3

import argparse
import logging
import os
import re
import tarfile
import tempfile
import requests
import simplediskimage
import lzma

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
    rootfs_tar = get_file(args.get('rootfs', None))
    output_file = args.get('output_file', None)

    uncompressed_file = output_file + '.tmp'
    image = simplediskimage.DiskImage(uncompressed_file,
                                      partition_table='null',
                                      partitioner=simplediskimage.NullPartitioner)
    part = image.new_partition("ext4")
    part.set_extra_bytes(200 * simplediskimage.SI.Mi)


    # Unpack the rootfs.tar file into a temporary directory
    with tempfile.TemporaryDirectory() as rootfs_dir:
        with tarfile.open(rootfs_tar, 'r:xz') as tf:
            tf.extractall(rootfs_dir)

        part.set_initial_data_root(rootfs_dir)

        image.commit()

    with open(output_file, "wb") as fout, open(uncompressed_file, 'rb') as fin:
        with lzma.open(fout, "w") as lzf:
            while True:
                data = fin.read(simplediskimage.SI.Mi)
                if data == b'':
                    break
                lzf.write(data)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--rootfs", required=True,
                        help="url or path to rootfs file")
    parser.add_argument("--output_file", required=True,
                        help="name the newly created .ext4.gz file")
    args = vars(parser.parse_args())
    if args:
        main(args)
    else:
        exit(1)
