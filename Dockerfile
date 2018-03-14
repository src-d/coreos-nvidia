FROM ubuntu:17.10 as BUILD
MAINTAINER source{d}

RUN apt-get -y update && \
    apt-get -y install curl git bc make dpkg-dev libssl-dev module-init-tools p7zip-full libelf-dev && \
    apt-get autoremove && \
    apt-get clean


ARG COREOS_RELEASE_CHANNEL=stable
ARG COREOS_VERSION
ARG NVIDIA_DRIVER_VERSION
ARG KERNEL_VERSION
ARG KERNEL_TAG

ENV KERNEL_PATH /usr/src/kernels/linux
ENV KERNEL_REPOSITORY git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
ENV COREOS_RELEASE_URL https://${COREOS_RELEASE_CHANNEL}.release.core-os.net/amd64-usr/${COREOS_VERSION}

RUN git clone ${KERNEL_REPOSITORY} \
        --single-branch \
        --depth 1 \
        --branch v${KERNEL_TAG} \
        ${KERNEL_PATH}

WORKDIR ${KERNEL_PATH}

RUN git checkout -b stable v${KERNEL_TAG} && rm -rf .git
RUN curl ${COREOS_RELEASE_URL}/coreos_developer_container.bin.bz2 | \
        bzip2 -d > /tmp/coreos_developer_container.bin
RUN 7z e /tmp/coreos_developer_container.bin "usr/lib64/modules/*-coreos*/build/.config"
RUN 7z e /tmp/coreos_developer_container.bin "usr/lib64/modules/*-coreos*/build/include/config/kernel.release" && cp kernel.release /tmp/kernel.release
RUN make modules_prepare
RUN sed -i -e "s/${KERNEL_VERSION}/$(cat /tmp/kernel.release)/" include/generated/utsrelease.h

ENV NVIDIA_DRIVER_URL http://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run

ENV NVIDIA_PATH /opt/nvidia
ENV NVIDIA_BUILD_PATH /opt/nvidia/build

# NVIDIA driver
WORKDIR ${NVIDIA_PATH}/download

RUN curl ${NVIDIA_DRIVER_URL} -o driver.run && \
    chmod +x driver.run
RUN ${NVIDIA_PATH}/download/driver.run \
        --accept-license \
        --extract-only \
        --ui=none

ENV NVIDIA_INSTALLER /opt/nvidia/download/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}/nvidia-installer
RUN ${NVIDIA_INSTALLER} \
    --accept-license \
    --no-questions \
    --ui=none \
    --no-precompiled-interface \
    --kernel-source-path=${KERNEL_PATH} \
    --kernel-name=$(cat /tmp/kernel.release) \
    --installer-prefix=${NVIDIA_BUILD_PATH} \
    --utility-prefix=${NVIDIA_BUILD_PATH} \
    --opengl-prefix=${NVIDIA_BUILD_PATH}

RUN mkdir  ${NVIDIA_BUILD_PATH}/lib/modules/ && \
    cp -rf /lib/modules/$(cat /tmp/kernel.release) ${NVIDIA_BUILD_PATH}/lib/modules/${KERNEL_VERSION}

FROM ubuntu:17.10
MAINTAINER source{d}

ARG COREOS_RELEASE_CHANNEL=stable
ARG COREOS_VERSION
ARG KERNEL_VERSION
ARG NVIDIA_DRIVER_VERSION

LABEL vendor="source{d}" \
      com.coreos.release-channel=${COREOS_RELEASE_CHANNEL} \
      com.coreos.version=${COREOS_VERSION} \
      com.coreos.kernel.version=${KERNEL_VERSION} \
      com.nvidia.driver.version=${NVIDIA_DRIVER_VERSION}

RUN apt-get -y update && \
    apt-get -y install module-init-tools pciutils && \
    apt-get autoremove && \
    apt-get clean

ENV COREOS_RELEASE_CHANNEL ${COREOS_RELEASE_CHANNEL}
ENV COREOS_VERSION ${COREOS_VERSION}
ENV NVIDIA_DRIVER_VERSION ${NVIDIA_DRIVER_VERSION}
ENV KERNEL_VERSION ${KERNEL_VERSION}

ENV NVIDIA_PATH /opt/nvidia
ENV NVIDIA_BIN_PATH ${NVIDIA_PATH}/bin
ENV NVIDIA_LIB_PATH ${NVIDIA_PATH}/lib
ENV NVIDIA_MODULES_PATH ${NVIDIA_LIB_PATH}/modules/${KERNEL_VERSION}/video

COPY --from=BUILD /opt/nvidia/build ${NVIDIA_PATH}
COPY scripts/nvidia-mkdevs ${NVIDIA_BIN_PATH}/nvidia-mkdevs

ENV PATH $PATH:${NVIDIA_BIN_PATH}
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${NVIDIA_LIB_PATH}

VOLUME ${NVIDIA_PATH}

CMD if ! lsmod | grep "ipmi_msghandler" &> /dev/null; then insmod `find /rootfs/usr -iname ipmi_msghandler.ko`; fi \
    if ! lsmod | grep "ipmi_devintf" &> /dev/null; then insmod `find /rootfs/usr -iname ipmi_devintf.ko`; fi && \
    insmod ${NVIDIA_MODULES_PATH}/nvidia.ko && \
    insmod ${NVIDIA_MODULES_PATH}/nvidia-uvm.ko && \
    nvidia-mkdevs
