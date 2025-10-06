Running builds for ucore-k8s

This repository builds a bootable Fedora-based image with `bootc` + `rpm-ostree`.

Requirements
- A Linux build environment (WSL2/Ubuntu, VM, or self-hosted runner) with rootful Podman/Buildah.
- The build requires privileged capabilities (mounts, systemd interactions). For reproducible CI runs you should use a self-hosted runner with a label such as `self-hosted-privileged` and run the job as a privileged user.

Quick local test (WSL2/Ubuntu)
1. Open WSL2 Ubuntu shell.
2. Install Podman/Buildah and make sure it's usable as root.
3. From the repo root run:

```bash
sudo podman build --no-cache -t test-ucore-k8s -f Containerfile .
```

CI (recommended)
- Use the provided `ci-call-build.yml` workflow to run the reusable build workflow. The called workflow accepts the following inputs:
  - arch, crio_version, kubernetes_version, enable_ceph, image_tag, runner
- The caller (`ci-call-build.yml`) uses `GITHUB_TOKEN` as the registry password by default, but for org-level pushes consider a PAT with `write:packages`.

Notes
- The Containerfile inserts `pkgs.k8s.io` repositories for Kubernetes and CRI-O when you provide `KUBERNETES_VERSION` and `CRIO_VERSION`. This follows the upstream recommendation.
- If you see package dependency errors, consider using a self-hosted Fedora runner or mirror the required pkgs.k8s.io release into an internal repository.

If you want, I can:
- Push a test run to GitHub Actions that invokes the caller with a real minor pair (1.26) and report back the logs.
- Help provisioning a self-hosted privileged runner (script + commands).
