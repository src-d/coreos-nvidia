
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
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=0
EnvironmentFile=/etc/os-release
ExecStart=/usr/bin/docker run --rm --privileged --volume /:/rootfs/ srcd/coreos-nvidia:${VERSION}

[Install]
WantedBy=multi-user.target
```

And now just enable and start the unit:

```sh
sudo systemctl enable /etc/systemd/system/coreos-nvidia.service
sudo systemctl start coreos-nvidia.service
```

## License

GPLv3, see [LICENSE](LICENSE)
