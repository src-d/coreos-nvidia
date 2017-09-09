FROM ubuntu:17.10
MAINTAINER source{d}

ENV RELEASE_CHANNEL stable
ENV COREOS_VERSION 1465.7.0
ENV DRIVER_VERSION 384.59
ENV KERNEL_VERSION 4.12.10

RUN apt-get -y update \
    && apt-get -y install wget git bc make dpkg-dev libssl-dev module-init-tools p7zip-full \
    && apt-get autoremove \
    && apt-get clean

ENV KERNEL_PATH /usr/src/kernels/linux
ENV KERNEL_NAME ${KERNEL_VERSION}-coreos
ENV KERNEL_REPOSITORY git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
ENV COREOS_RELEASE_URL https://${RELEASE_CHANNEL}.release.core-os.net/amd64-usr/${COREOS_VERSION}

# Download Phase
RUN mkdir -p ${KERNEL_PATH} && \
    git clone ${KERNEL_REPOSITORY} \
        --single-branch \
        --depth 1 \
        --branch v${KERNEL_VERSION} \
        ${KERNEL_PATH} && \
    cd ${KERNEL_PATH} && \
    git checkout -b stable v${KERNEL_VERSION} && \
    wget ${COREOS_RELEASE_URL}/coreos_developer_container.bin.bz2 \
        --output-document /tmp/coreos_developer_container.bin.bz2 && \
    bzip2 -d /tmp/coreos_developer_container.bin.bz2 && \
    7z e /tmp/coreos_developer_container.bin "usr/lib64/modules/*-coreos/build/.config"

RUN cd ${KERNEL_PATH} && \
    make modules_prepare && \
    sed -i -e "s/${KERNEL_VERSION}/${KERNEL_NAME}/" include/generated/utsrelease.h

ENV NVIDIA_DRIVER_URL http://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run

# NVIDIA driver
RUN mkdir -p /opt/nvidia && \
    cd /opt/nvidia/ && \
    wget ${NVIDIA_DRIVER_URL} -O /opt/nvidia/driver.run \
    && chmod +x /opt/nvidia/driver.run \
    && /opt/nvidia/driver.run \
        --accept-license \
        --extract-only \
        --ui=none

ENV NVIDIA_INSTALLER /opt/nvidia/NVIDIA-Linux-x86_64-${DRIVER_VERSION}/nvidia-installer
RUN ${NVIDIA_INSTALLER} \
    --accept-license \
    --no-questions \
    --ui=none \
    --no-precompiled-interface \
    --kernel-source-path=${KERNEL_PATH} \
    --kernel-name=${KERNEL_NAME}


# insmod /lib/modules/`uname -r`/video/nvidia.ko \
# insmod /lib/modules/`uname -r`/video/nvidia-uvm.ko


# ONBUILD, we install the NVIDIA driver and the cuda libraries
ONBUILD ENV CUDA_VERSION 8.0.44

ONBUILD RUN /opt/nvidia/driver.run --silent --no-kernel-module --no-unified-memory --no-opengl-files
ONBUILD RUN wget --no-check-certificate http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_${CUDA_VERSION}-1_amd64.deb \
    && dpkg -i cuda-repo-ubuntu1604_${CUDA_VERSION}-1_amd64.deb \
    && apt-get -y update \
    && apt-get -y install --no-install-suggests --no-install-recommends \
        cuda-command-line-tools-8.0 \
        cuda-nvgraph-dev-8.0 \
        cuda-cusparse-dev-8.0 \
        cuda-cublas-dev-8.0 \
        cuda-curand-dev-8.0 \
        cuda-cufft-dev-8.0 \
        cuda-cusolver-dev-8.0 \
    && sed -i 's#"$#:/usr/local/cuda-8.0/bin"#' /etc/environment \
    && rm cuda-repo-ubuntu1604_${CUDA_VERSION}-1_amd64.deb \
    && cd /usr/local/cuda-8.0 && ln -s . cuda \
    && wget http://developer.download.nvidia.com/compute/redist/cudnn/v5.1/cudnn-8.0-linux-x64-v5.1.tgz \
    && tar -xf cudnn-8.0-linux-x64-v5.1.tgz \
    && rm cudnn-8.0-linux-x64-v5.1.tgz

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/cuda-8.0/bin
