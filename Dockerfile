FROM ubuntu:focal

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
# Install tini: init for containers
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    tini \
    wget \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    HOME="/home/${NB_USER}"

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}"


# Podman
# Source: https://github.com/containers/podman/blob/056f492f59c333d521ebbbe186abde0278e815db/contrib/podmanimage/stable/Dockerfile
RUN apt-get update && \
    apt-get -y install ca-certificates curl gnupg unzip && \
    . /etc/os-release && \
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list && \
    curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | apt-key add - && \
    apt-get update && \
    apt-get -y install podman fuse-overlayfs && \
    rm -rf /var/lib/apt/lists/*

COPY podman/containers.conf /etc/containers/containers.conf
COPY podman/storage.conf /etc/containers/storage.conf
COPY podman/containers-user.conf /home/$NB_USER/.config/containers/containers.conf
COPY podman/storage-user.conf /home/$NB_USER/.config/containers/storage.conf

# Create empty storage not to get errors when it's not mounted 
# See: https://www.redhat.com/sysadmin/image-stores-podman
RUN mkdir -p \
    /var/lib/containers/shared/overlay-images \ 
    /var/lib/containers/shared/overlay-layers \
    /var/lib/containers/shared/vfs-images \
    /var/lib/containers/shared/vfs-layers && \
    touch /var/lib/containers/shared/overlay-images/images.lock && \
    touch /var/lib/containers/shared/overlay-layers/layers.lock && \
    touch /var/lib/containers/shared/vfs-images/images.lock && \
    touch /var/lib/containers/shared/vfs-layers/layers.lock

RUN fix-permissions "${HOME}"

USER $NB_USER
ENTRYPOINT ["tini", "-g", "--"]
CMD ["bash"]