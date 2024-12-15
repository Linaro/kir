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
RUN echo "\n\
Types: deb \n\
# http://snapshot.debian.org/archive/debian/20231009T000000Z \n\
URIs: http://deb.debian.org/debian \n\
Suites: bookworm-backports \n\
Components: main \n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg " >> /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
    && apt-get install -qy \
      android-sdk-libsparse-utils/bookworm-backports \
      fastboot/bookworm-backports
COPY . /kir
