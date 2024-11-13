FROM nixos/nix AS base

# arm64-specific stage
FROM base AS build-arm64

RUN <<EOR
tee /etc/nix/nix.conf << EOF
build-users-group = nixbld
filter-syscalls = false
sandbox = true
experimental-features = nix-command flakes
substitute = true
substituters = https://cache.nixos.org https://nix-community.cachix.org https://superbird.attic.claiborne.soy/superbird
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= superbird:r9Hm/REl7BEr6+9UQoS+nxzqxY2sKUhsDCNy5PGQbDU=
EOF
EOR

RUN nix-channel --update

# end arm64-specific stage

# amd64-specific stage
FROM base AS build-amd64

RUN <<EOR
tee /etc/nix/nix.conf << EOF
build-users-group = nixbld
filter-syscalls = false
sandbox = true
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
substitute = true
substituters = https://cache.nixos.org https://nix-community.cachix.org https://superbird.attic.claiborne.soy/superbird
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= superbird:r9Hm/REl7BEr6+9UQoS+nxzqxY2sKUhsDCNy5PGQbDU=
EOF
EOR

RUN nix-channel --update

RUN nix-env -iA nixpkgs.qemu

# end amd64-specific stage

# shared stage
FROM build-${TARGETARCH} AS build

RUN nix-env -iA \
  nixpkgs.git \
  nixpkgs.util-linux \
  nixpkgs.btrfs-progs \
  nixpkgs.gawk \
  nixpkgs.perl

RUN git config --global --add safe.directory /workdir

WORKDIR /workdir

COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="JoeyEamigh"
LABEL org.opencontainers.image.url="https://github.com/JoeyEamigh/nixos-superbird"
LABEL org.opencontainers.image.source="https://github.com/JoeyEamigh/nixos-superbird"
LABEL org.opencontainers.image.title="NixOS Superbird Builder"
LABEL org.opencontainers.image.description="Container to build Linux for the Spotify Car Thing"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/build.sh"]