FROM debian:buster
RUN apt-get update \
    && apt-get install -qy auto-apt-proxy \
    && apt-get install -qy \
      adb \
      android-sdk-libsparse-utils \
      fastboot \
      cpio \
      curl \
      file \
      git \
      img2simg \
      libguestfs-tools \
      linux-image-amd64 \
      mkbootimg \
      xz-utils \
      --no-install-recommends
COPY . /kir
