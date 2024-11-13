FROM ubuntu:22.04

# Install basic utilities and required tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    xz-utils \
    sudo \
    zip \
    unzip \
    perl \
    btrfs-progs \
    util-linux \
    python3 \
    python3-pip \
    coreutils \
    git \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install pyroute2

# Create nix config directories
RUN mkdir -p /etc/nix /root/.config/nix && \
    echo "build-users-group =" > /etc/nix/nix.conf && \
    echo 'experimental-features = nix-command flakes' > /root/.config/nix/nix.conf && \
    echo 'system-features = kvm nixos-test benchmark big-parallel' >> /root/.config/nix/nix.conf && \
    echo 'extra-platforms = aarch64-linux' >> /root/.config/nix/nix.conf && \
    echo 'substituters = https://cache.nixos.org https://nix-community.cachix.org' >> /root/.config/nix/nix.conf && \
    echo 'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=' >> /root/.config/nix/nix.conf

# Install Nix
RUN curl -L https://nixos.org/nix/install | sh -s -- --daemon

# Add Nix to PATH for subsequent commands
ENV PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:${PATH}"

# Configure Git to trust the Docker mounted directory
RUN git config --global --add safe.directory /workdir

# Initialize nix and install packages
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh && \
    nix-daemon & \
    sleep 2 && \
    nix-channel --update && \
    nix-env -iA \
        nixpkgs.just \
        nixpkgs.deploy-rs \
        nixpkgs.qemu

WORKDIR /workdir

# Copy and set up entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash", "--login"]