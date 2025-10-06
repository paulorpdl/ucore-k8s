# ucore-k8s (bootc image)

Bootable Fedora-based image with **Kubernetes (kubelet/kubeadm/kubectl)**, **CRI-O**, and baseline storage tooling **baked-in**. No first-boot layering; suitable for FCOS-style provisioning via **Ignition**.

## Goals
- Immutable, reproducible image for K8s nodes.
- CRI-O + kubelet pre-enabled; sysctls and modules baked-in.
- Optional storage helpers for Rook/Ceph (future).

## Versioning
Tag the repo with the target **Kubernetes minor** (e.g., `v1.34`). Keep CRI-O minor aligned with K8s.

## Build & Publish
```bash
make build
make push
```
or via GitHub Actions (push to `main`).

## Using with Ignition
This image expects `kubelet-config.yaml`, kubeconfigs, and (on control-plane) static pod manifests to be provided by Ignition at first boot. Pair with the `ign-k8sctl` CLI.

---

## Context for GitHub Copilot
- **Primary tasks**: modify Containerfile and `files/` to pin versions; expand CI to produce ISO/RAW/QCOW with bootc-image-builder; add multi-arch builds.
- **Constraints**: do *not* add first-boot installers or oneshot services; everything must be baked into the image.
- **Paths**: keep Kubernetes artifacts under `/etc/kubernetes/*`, CRI-O socket at `/var/run/crio/crio.sock`.
- **SELinux**: remain enforcing; use standard paths to avoid custom labels.
- **Networking**: modules `overlay` & `br_netfilter`; sysctls as provided.
