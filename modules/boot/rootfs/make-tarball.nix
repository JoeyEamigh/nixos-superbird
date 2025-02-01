{
  pkgs,
  storePaths,
  populateImageCommands ? "",
  perl,
}:

let
  tarballClosureInfo = pkgs.buildPackages.closureInfo { rootPaths = storePaths; };
in
pkgs.stdenv.mkDerivation {
  name = "nixos-fs.tar.gz";

  nativeBuildInputs = [
    perl
  ];

  buildCommand = ''
    tarball=nixos-fs.tar.gz
    (
    mkdir -p ./files
    ${populateImageCommands}
    )
    echo "Preparing store paths for image..."
    # Create nix/store before copying path
    mkdir -p ./rootImage/nix/store
    xargs -I % cp -a --reflink=auto % -t ./rootImage/nix/store/ < ${tarballClosureInfo}/store-paths
    (
      GLOBIGNORE=".:.."
      shopt -u dotglob
      for f in ./files/*; do
          cp -a --reflink=auto -t ./rootImage/ "$f"
      done
    )
    # Also include a manifest of the closures in a format suitable for nix-store --load-db
    cp ${tarballClosureInfo}/registration ./rootImage/nix-path-registration

    echo "tarring image..."
    tar -C ./rootImage -czf $out .
  '';
}
