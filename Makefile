IMAGE ?= ghcr.io/your-org/ucore-k8s:dev

.PHONY: build push iso qemu
build:
	podman build -t $(IMAGE) -f Containerfile .

push:
	podman push $(IMAGE)

iso:
	# Requires bootc-image-builder installed locally
	# bootc-image-builder --type iso --local --rootfs ./ --image $(IMAGE) --output ./dist

qemu:
	# Example: quick boot test with QCOW (if generated)
	# qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm -drive file=./dist/disk.qcow2,if=virtio
