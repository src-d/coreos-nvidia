
# Container Linux (aka CoreOS) NVIDIA Driver [![Build Status](https://travis-ci.org/src-d/coreos-nvidia.svg?branch=master)](https://travis-ci.org/src-d/coreos-nvidia)

Yet another NVIDIA driver container for Container Linux (aka CoreOS).

Many different solutions to load the NVIDIA modules in a CoreOS kernel has been created during the last years, this is just another one trying to fit the *source{d}* requirements:

- Load the NVIDIA modules in the kernel of the host.
- Make available the NVIDIA libraries and binaries to other containers.
- Works with unmodified third-party containers.
- Avoid permanent changes on the host system.

## Contents

* [Hot it works](#how-it-works)
* [Installation](#installation)
* [Usage](#usage)
* [Available Images]($available-images)
* [Custom images](#custom-images)

## How it works

Executing the `srcd/coreos-nvidia` for your CoreOS version the nvidia modules are loaded in the kernel and the devices are created in the rootfs.

```sh
source /etc/os-release
docker run --rm --privileged --volume /:/rootfs/ srcd/coreos-nvidia:${VERSION}
```

You can test the execution running the next command:

```sh
docker run --rm $(for d in /dev/nvidia*; do echo -n "--device $d "; done) \
    srcd/coreos-nvidia:${VERSION} nvidia-smi -L

// Outputs:
// GPU 0: Tesla K80 (UUID: GPU-d57ec7e8-ab97-8612-54ac-9d53a183f818)
```

## Installation

The installation is done using a systemd unit, this unit has two goals:

- Load the modules in the kernel in every startup, unload it if the service is stopped.
- Keep running a docker container called `nvidia-driver` to allow other images access to the libraries and binaries from the NVIDIA driver, using the `--volumes-from`.

Create the following systemd unit at `/etc/systemd/system/coreos-nvidia.service`:

```sh
[Unit]
Description=NVIDIA driver
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=20m
EnvironmentFile=/etc/os-release
ExecStartPre=-/usr/bin/docker rm nvidia-driver
ExecStartPre=/usr/bin/docker run --rm --privileged --volume /:/rootfs/ srcd/coreos-nvidia:${VERSION}
ExecStart=/usr/bin/docker run --rm --name nvidia-driver srcd/coreos-nvidia:${VERSION} sleep infinity
ExecStop=/usr/bin/docker stop nvidia-driver
ExecStop=-/sbin/rmmod nvidia_uvm nvidia

[Install]
WantedBy=multi-user.target
```

And now just enable and start the unit:

```sh
sudo systemctl enable /etc/systemd/system/coreos-nvidia.service
sudo systemctl start coreos-nvidia.service
```


After start the service we should see the modules loaded in the kernel:

```
lsmod | grep -i nvidia
```
```
nvidia_uvm            679936  0
nvidia              12980224  1 nvidia_uvm
```

And the `nvidia-driver` container running:

```
docker ps | grep -i nvidia-driver
```
```
8cea48f9d556   srcd/coreos-nvidia:1465.7.0   "sleep infinity"   11 hours ago   nvidia-driver
```

## Usage

To easily use the NVIDIA driver in other standard containers, we use the `--volumes-from`, this requires to run a container based on our image, the `/dev/nvidia*` devices and a setting the  `$PATH` and `$LD_LIBRARY_PATH` variables to make it work properly.

A simple example running `nvidia-smi` in a bare `fedora` container:

```sh
docker run --rm -it \
    --volumes-from nvidia-driver \
    --env PATH=$PATH:/opt/nvidia/bin/ \
    --env LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nvidia/lib \
    $(for d in /dev/nvidia*; do echo -n "--device $d "; done) \
    fedora:26 nvidia-smi
```

Running the `tensorflow` GPU enabled container and verifying the identified devices:

```sh
docker run --rm -it \
    --volumes-from nvidia-driver \
    --env PATH=$PATH:/opt/nvidia/bin/ \
    --env LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nvidia/lib \
    $(for d in /dev/nvidia*; do echo -n "--device $d "; done) \
    gcr.io/tensorflow/tensorflow:latest-gpu \
        python -c "import tensorflow as tf;tf.Session(config=tf.ConfigProto(log_device_placement=True))"

```

## Available Images

Eventually an image for all the Container Linux version for all the release channels should be available, to ensure this, a Travis cron is executed everyday that checks if a new Container Linux versions exists, if exists a new image will be created.

The list of images is available at: [https://hub.docker.com/r/srcd/coreos-nvidia/tags/](https://hub.docker.com/r/srcd/coreos-nvidia/tags/).

### What I can do if I can't find an image for my version?

If your version was released today, you must to wait until the nightly cron. If wasn't released today and was after *11/Oct/2016*, open an issue, something has failed. If you image is older than this you must to build the image from the Dockerfile.

## Custom images

The builds of the Docker image are managed by a Makefile.

To build a image fot the latest stable version of Linux Container and the latest version of the NVIDIA driver just execute:

```
make build
```

The configuration is done through environment variables, for example if you want to build the image for the latest alpha version you can execute:

```
COREOS_RELEASE_CHANNEL=alpha make build
```

### Variables:

- `COREOS_RELEASE_CHANNEL`: Linux Container release channel: `stable`, `beta` or `alpha`. By default `stable`
- `COREOS_VERSION`: Linux Container version, if empty the last available version for the given release channel will be used. The version is retrieved making a request to the release feed.
- `NVIDIA_DRIVER_VERSION`: NVIDIA Driver version, if empty the last available version will be used. The version is retrieve from https://github.com/aaronp24/nvidia-versions/.
- `KERNEL_VERSION`: Kernel version used in the given `COREOS_VERSION`, if empty is retrieve from the CoreOS release feed.


## License

GPLv3, see [LICENSE](LICENSE)

