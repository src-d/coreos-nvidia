
# Container Linux (aka CoreOS) NVIDIA Driver

Yet another NVIDIA driver container for Container Linux (aka CoreOS).

## Usage

### Manual execution

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

### Systemd Unit

Since the changes made by the container aren't permanent, the container should be executed in every boot.

The best way to ensure this, is create the following systemd unit at `/etc/systemd/system/coreos-nvidia.service`:

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

### The driver in other containers

To easily use the NVIDIA driver in other standard containers, we use the `--volumes-from`, this requires to run a container based on our image, the `/dev/nvidia*` devices and a few environment variables to make it work properly.

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

## License

GPLv3, see [LICENSE](LICENSE)

