# ===== stage: toolchain
FROM debian:bookworm AS toolchain
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /build
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    tar \
    build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY buildconf/download-arm-toolchain.sh /build/
RUN /build/download-arm-toolchain.sh linux && \
    /build/download-arm-toolchain.sh none

# ===== stage: build container
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV IN_CONTAINER=1
ENV HOME=/root

# XXX: wrap all packages into single RUN command
#      to save space in docker layers

# Install all dependencies
RUN apt-get update -y && apt-get install -y \
    # -------------------------
    # Basic tools
    # -------------------------
    build-essential \
    autoconf \
    automake \
    libtool \
    ccache \
    device-tree-compiler \
    emacs-nox \
    nano \
    vim \
    sudo \
    curl \
    wget \
    git \
    unzip \
    htop \
    tmux \
    screen \
    bash-completion \
    lsof \
    fish \
    iproute2 \
    net-tools \
    dnsutils \
    iputils-ping \
    traceroute \
    socat \
    tcpdump \
    nmap \
    cmake \
    pkg-config \
    gdb \
    gdb-multiarch \
    strace \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    telnet \
    xterm \
    sshpass \
    usbutils \
    udev \
    libusb-1.0-0-dev \
    coreutils \
    expect \
    # -------------------------
    # U-Boot build tools
    # -------------------------
    bc \
    bison \
    coccinelle \
    dfu-util \
    efitools \
    flex \
    gdisk \
    graphviz \
    imagemagick \
    liblz4-tool \
    libgnutls28-dev \
    libguestfs-tools \
    libncurses-dev \
    libpython3-dev \
    libsdl2-dev \
    libssl-dev \
    lz4 \
    lzma \
    lzma-alone \
    openssl \
    python3-asteval \
    python3-coverage \
    python3-filelock \
    python3-pkg-resources \
    python3-pycryptodome \
    python3-pyelftools \
    python3-pytest \
    python3-pytest-xdist \
    python3-sphinxcontrib.apidoc \
    python3-sphinx-rtd-theme \
    python3-subunit \
    python3-testtools \
    python3-virtualenv \
    swig \
    uuid-dev \
    # -------------------------
    # Buildroot
    # -------------------------
    rsync \
    file \
    cpio \
    gawk \
    texinfo \
    bzip2 \
    xz-utils \
    patch \
    qemu-system \
    qemu-user \
    qemu-user-static \
    dosfstools \
    mtools \
    genext2fs \
    fakeroot \
    libelf-dev \
    qemu-system-x86 \
    ninja-build \
    libtool \
    g++ \
    zlib1g-dev \
    gperf \
    # -------------------------
    # Debos
    # -------------------------
    libostree-1-1 \
    ca-certificates \
    systemd-container \
    binfmt-support \
    parted \
    e2fsprogs \
    bmap-tools \
    busybox \
    linux-image-amd64 \
    systemd \
    dbus \
    systemd-resolved \
    mmdebstrap \
    pigz \
    user-mode-linux \
    golang \
    libglib2.0-dev \
    crossbuild-essential-arm64 \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    libostree-dev \
    debootstrap \
    debhelper-compat \
    gcc-aarch64-linux-gnu && \
    rm -rf /var/lib/apt/lists/*


# Python
RUN ln -s /usr/bin/python3 /usr/bin/python || true
RUN pip3 install --no-cache-dir dtschema --break-system-packages

# PATH
ENV PATH="/root/.local/bin:/build/aarch64-none-elf/bin:/build/aarch64-none-linux-gnu/bin:$PATH"

# Toolchain
COPY --from=toolchain /build/ /build/

# Ccache
ENV CCACHE_DIR="/build/.ccache"
RUN ccache --max-size=10G

# Buildroot
ENV FORCE_UNSAFE_CONFIGURE=1

# Install Debos
ENV GOPATH=/build/gocode
RUN go install -v github.com/go-debos/debos/cmd/debos@latest
RUN /build/gocode/bin/debos --help

ENV PATH="/build/gocode/bin:$PATH"

# Install Repo tool
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo && \
    chmod a+x /usr/local/bin/repo

# Allow git inside container
RUN git config --global --add safe.directory "*"

# For CI build
ARG RELEASE_BUILD_DATE
ARG RELEASE_VCS_REF
ARG RELEASE_VERSION
LABEL org.opencontainers.image.created=$RELASE_BUILD_DATE
LABEL org.opencontainers.image.version=$RELASE_VERSION
LABEL org.opencontainers.image.revision=$RELASE_VCS_REF
LABEL org.opencontainers.image.source="https://github.com/opencca/opencca-build"
LABEL org.opencontainers.image.description="OpenCCA Build Environment"
LABEL org.opencontainers.image.authors="Andrin Bertschi <hi@abertschi.ch>"
LABEL org.opencontainers.image.licenses="MIT"

CMD ["/bin/bash"]
