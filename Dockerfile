FROM ubuntu:16.04
MAINTAINER source{d} 

ENV DRIVER_VERSION 384.59

RUN apt-get -y update \
    && apt-get -y install wget git bc make dpkg-dev libssl-dev module-init-tools \
    && apt-get autoremove \
    && apt-get clean

# kernel modules
RUN  mkdir -p /usr/src/kernels \
    && cd /usr/src/kernels \
    && git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git --single-branch --depth 1 --branch v`uname -r | sed -e "s/-.*//" | sed -e "s/\.[0]*$//"`  linux \
    && cd linux \
    && git checkout -b stable v`uname -r | sed -e "s/-.*//" | sed -e "s/\.[0]*$//"` \
    && zcat /proc/config.gz > .config \
    && make modules_prepare \
    && sed -i -e "s/`uname -r | sed -e "s/-.*//" | sed -e "s/\.[0]??*$//"`/`uname -r`/" include/generated/utsrelease.h # In case a '+' was added

# NVIDIA driver
RUN mkdir -p /opt/nvidia && cd /opt/nvidia/ \
    && wget http://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run -O /opt/nvidia/driver.run \ 
    && chmod +x /opt/nvidia/driver.run \
    && /opt/nvidia/driver.run -a -x --ui=none

ENV NVIDIA_INSTALLER /opt/nvidia/NVIDIA-Linux-x86_64-${DRIVER_VERSION}/nvidia-installer
CMD ${NVIDIA_INSTALLER} -q -a -n -s --kernel-source-path=/usr/src/kernels/linux/ \
    && insmod /lib/modules/`uname -r`/video/nvidia.ko \
    && insmod /lib/modules/`uname -r`/video/nvidia-uvm.ko


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
