FROM quay.io/fedora/fedora-iot:43

# Label for metadata
LABEL com.github.containers.bootc=true \
      description="Fedora IoT 43 with bcachefs support"

# 1. Add the bcachefs repository
# We use ADD to pull the .repo file directly to the correct location
ADD https://download.opensuse.org/repositories/filesystems:/bcachefs:/release/Fedora_43/filesystems:bcachefs:release.repo \
    /etc/yum.repos.d/filesystems:bcachefs.repo

# 2. Install dependencies, build the module, and cleanup
# We combine these into one RUN block to reduce layer size
RUN set -e && \
    # Install bcachefs tools, dkms source, and build requirements
    dnf install -y \
        bcachefs-tools \
        dkms-bcachefs \
        kernel-devel \
        gcc \
        make \
        diffutils \
        kmod && \
    \
    # CRITICAL STEP: Identify the kernel version installed *inside* the container image.
    # Standard `uname -r` would return the *build host's* kernel, which causes build failures.
    KVER=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-core | head -n 1) && \
    echo "Building bcachefs for target kernel: $KVER" && \
    \
    # Build and install the module specifically for the container's kernel version
    dkms autoinstall -k $KVER && \
    \
    # Update module dependencies so the kernel can find the new .ko file
    depmod -a $KVER && \
    \
    # Cleanup build dependencies to keep the IoT image slim
    # We keep bcachefs-tools and the compiled module, but remove gcc/headers
    dnf remove -y kernel-devel gcc make && \
    dnf clean all

# Ensure the container is bootable
# (bootc images generally imply CMD/ENTRYPOINT handling by systemd, but explicit is fine)
CMD ["/sbin/init"]
