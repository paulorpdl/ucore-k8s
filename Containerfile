ARG ARCH=amd64
ARG BASE_IMAGE=quay.io/fedora/fedora-bootc
ARG BASE_TAG=latest
ARG KUBERNETES_VERSION
ARG CRIO_VERSION
ARG ENABLE_CEPH=false

# Base bootc Fedora image (allow overriding base image and tag)
FROM ${BASE_IMAGE}:${BASE_TAG}
 
# Re-declare build args in the build stage so they're available inside RUN
ARG KUBERNETES_VERSION
ARG CRIO_VERSION
ARG ENABLE_CEPH=false

# Note: bootc install is NOT run during container build - it should be run separately
# after the container image is built using: podman run --privileged ... <image> bootc install ...

# Repo templates (used to generate repo files at build time)
COPY files/repo-templates/kubernetes.repo.tpl /repo-templates/kubernetes.repo.tpl
COPY files/repo-templates/crio.repo.tpl /repo-templates/crio.repo.tpl

# Install Kubernetes + CRI-O + storage tools (baked-in; no first-boot layering)
# Support optional CRI-O and Kubernetes version pins and optional Ceph tools
RUN set -eux; \
	# We install kubelet and kubectl only (no kubeadm for CoreOS/ignition-managed clusters).
	# Do not add kube packages here - add them later with optional version suffix so rpm-ostree can find exact versions.
	PKGS="cri-tools lvm2 nvme-cli smartmontools sg3_utils xfsprogs btrfs-progs mdadm chrony container-selinux iproute iptables conntrack-tools"; \
	\
	# Validate CRI-O and Kubernetes major.minor compatibility if both provided
	if [ -n "${CRIO_VERSION}" ] && [ -n "${KUBERNETES_VERSION}" ]; then \
		# Extract MAJOR.MINOR from X.Y(.Z) style strings
		crio_mm=$(printf "%s" "${CRIO_VERSION}" | awk -F. '{print $1"."$2}'); \
		kube_mm=$(printf "%s" "${KUBERNETES_VERSION}" | awk -F. '{print $1"."$2}'); \
		if [ "$crio_mm" != "$kube_mm" ]; then \
			echo "ERROR: CRI-O version ($CRIO_VERSION -> $crio_mm) is not compatible with Kubernetes version ($KUBERNETES_VERSION -> $kube_mm)." >&2; \
			echo "CRI-O and Kubernetes must match at least major.minor (e.g. 1.26)." >&2; \
			exit 1; \
		fi; \
	fi; \
	# Add cri-o package (optionally with version)
	if [ -n "${CRIO_VERSION}" ]; then \
		PKGS="$PKGS cri-o-${CRIO_VERSION}"; \
	else \
		PKGS="$PKGS cri-o"; \
	fi; \
	# Add kubelet and kubectl (optionally pinned to a specific KUBERNETES_VERSION)
	if [ -n "${KUBERNETES_VERSION}" ]; then \
		PKGS="$PKGS kubelet-${KUBERNETES_VERSION} kubectl-${KUBERNETES_VERSION}"; \
	else \
		PKGS="$PKGS kubelet kubectl"; \
	fi; \
	# If user requests Ceph tools, include ceph-common
	if [ "${ENABLE_CEPH}" = "true" ]; then \
		PKGS="$PKGS ceph-common"; \
	fi; \
	\
	# Add pkgs.k8s.io repositories for Kubernetes and CRI-O (community-owned)
	# Use major.minor (v1.26 -> v1.26) repository layout
	# Use repo templates (copied into image context) and substitute values
	if [ -n "${KUBERNETES_VERSION}" ]; then \
		kube_mm=$(printf "%s" "${KUBERNETES_VERSION}" | awk -F. '{print $1"."$2}'); \
		kube_base="https://pkgs.k8s.io/core:/stable:/v${kube_mm}/rpm/"; \
		echo "Generating Kubernetes repo from template for v${kube_mm}"; \
		sed -e "s|{{KUBE_MM}}|${kube_mm}|g" -e "s|{{KUBE_BASE}}|${kube_base}|g" /repo-templates/kubernetes.repo.tpl > /etc/yum.repos.d/kubernetes.repo; \
		# quick availability check for kube repo
		if ! curl -fsS --retry 3 "${kube_base}repodata/repomd.xml" >/dev/null 2>&1; then \
			echo "ERROR: Kubernetes pkgs repo not reachable at ${kube_base}" >&2; \
			exit 1; \
		fi; \
		if ! curl -fsS --retry 3 "${kube_base}repodata/repomd.xml.key" >/dev/null 2>&1; then \
			echo "WARNING: Kubernetes gpg key not reachable at ${kube_base}repodata/repomd.xml.key" >&2; \
		fi; \
	fi; \
	if [ -n "${CRIO_VERSION}" ]; then \
		crio_mm=$(printf "%s" "${CRIO_VERSION}" | awk -F. '{print $1"."$2}'); \
		crio_base="https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v${crio_mm}/rpm/"; \
		echo "Generating CRI-O repo from template for ${crio_mm}"; \
		sed -e "s|{{CRIO_MM}}|${crio_mm}|g" -e "s|{{CRIO_BASE}}|${crio_base}|g" /repo-templates/crio.repo.tpl > /etc/yum.repos.d/crio.repo; \
		# quick availability check for cri-o repo
		if ! curl -fsS --retry 3 "${crio_base}repodata/repomd.xml" >/dev/null 2>&1; then \
			echo "ERROR: CRI-O pkgs repo not reachable at ${crio_base}" >&2; \
			exit 1; \
		fi; \
		if ! curl -fsS --retry 3 "${crio_base}repodata/repomd.xml.key" >/dev/null 2>&1; then \
			echo "WARNING: CRI-O gpg key not reachable at ${crio_base}repodata/repomd.xml.key" >&2; \
		fi; \
	fi; \
	# Try installing the requested packages. If exact versioned names aren't found,
	# try a wildcarded major.minor match (e.g. kubelet-1.32*) since repo NEVRAs may
	# include release suffixes. If that fails, fall back to unversioned names.
	if rpm-ostree install $PKGS; then \
		rpm-ostree cleanup -m; \
	else \
		echo "Versioned kube packages not found; trying wildcarded kubelet/kubectl (e.g. 1.32*)"; \
		# Construct wildcarded PKGS (replace kubelet-1.32.0 -> kubelet-1.32*)
		PKGS_WILDCARD=$(printf "%s" "$PKGS" | sed -E 's/(kubelet-|kubectl-)([0-9]+\.[0-9]+)\.[0-9]+/\1\2*/g'); \
		if rpm-ostree install $PKGS_WILDCARD; then \
			rpm-ostree cleanup -m; \
		else \
			echo "Wildcarded kube packages not found, retrying with unversioned kubelet/kubectl"; \
			PKGS_FALLBACK=$(printf "%s" "$PKGS" | sed -E 's/kubelet-[^ ]+//g; s/kubectl-[^ ]+//g'); \
			PKGS_FALLBACK="$PKGS_FALLBACK kubelet kubectl"; \
			rpm-ostree install $PKGS_FALLBACK && rpm-ostree cleanup -m; \
		fi; \
	fi

# Copy baked-in configs
COPY files/etc/modules-load.d/k8s.conf /etc/modules-load.d/k8s.conf
COPY files/etc/modules-load.d/ceph.conf /etc/modules-load.d/ceph.conf
COPY files/etc/sysctl.d/99-k8s-ceph.conf /etc/sysctl.d/99-k8s-ceph.conf

# Kubelet drop-in (CRI-O + systemd cgroups + external config file path)
RUN mkdir -p /etc/systemd/system/kubelet.service.d
COPY files/etc/systemd/system/kubelet.service.d/10-extra-args.conf      /etc/systemd/system/kubelet.service.d/10-extra-args.conf

# Enable services at image build-time
RUN systemctl enable crio kubelet chronyd

# Add bootc compatibility label
LABEL containers.bootc=1
