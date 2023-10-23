FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -qy auto-apt-proxy \
    && apt-get install -qy \
      adb \
      android-sdk-libsparse-utils \
      fastboot \
      cpio \
      curl \
      dosfstools \
      e2fsprogs \
      file \
      git \
      libguestfs-tools \
      linux-image-$(dpkg --print-architecture) \
      mkbootimg \
      mtools \
      python3-distutils \
      python3-parted \
      python3-pip \
      python3-requests \
      xz-utils \
      --no-install-recommends
RUN pip3 install --break-system-packages setuptools wheel simplediskimage==0.4.2
COPY . /kir
