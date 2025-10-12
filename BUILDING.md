# Building ucore-k8s

This repository builds a bootable Fedora-based image with **bootc** architecture for Kubernetes nodes.

## bootc Architecture

This project uses **bootc** (boot container) architecture, which has two distinct phases:

1. **Container Build**: Creates a container image with all the necessary packages and configuration
2. **Bootable Image Creation**: Converts the container image into a bootable disk/ISO using specialized tools

**Important**: bootc install commands CANNOT run during container build - they require a privileged environment that's separate from the build process.

## Building the Container Image

### Local Build
```bash
podman build -t ucore-k8s:1.33.5 \
  --build-arg KUBERNETES_VERSION=1.33.5 \
  --build-arg CRIO_VERSION=1.33.5 \
  -f Containerfile .
```

### Using Makefile
```bash
make build
```

## Creating Bootable Images

After building the container, use official bootc tooling:

### Raw Disk Image
```bash
make raw-image
# Creates ucore-k8s.raw (10GB disk image)
```

### ISO Image  
```bash
make iso
# Creates ucore-k8s.iso (bootable installer)
```

### Testing with QEMU
```bash
make qemu
# Boots the raw image in QEMU
```

### VM Installation
```bash
make virt-install
# Creates VM using virt-install with proper virtio drivers
```

## Requirements

- **Rootless Podman**: Container builds work with rootless podman
- **bootc-image-builder**: Required for creating bootable images (installed via toolbox/distrobox if needed)
- **Privileged access**: Only needed for bootc-image-builder operations, not container builds

## CI/CD Notes

- Container builds work in standard GitHub Actions runners (no --privileged needed)
- bootc-image-builder requires privileged runners for creating bootable images
- The workflow automatically handles version alignment between Kubernetes and CRI-O

## Ignition Configuration

Create bootc systems with Ignition for first-boot configuration:

```bash
# Convert Butane to Ignition
butane < config.bu > config.ign

# Use with bootc install
bootc install to-disk --via-loopback /dev/sda --ignition-file config.ign
```
