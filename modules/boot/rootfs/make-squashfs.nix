{
  lib,
  stdenv,
  squashfsTools,
  closureInfo,

  fileName ? "squashfs",
  # The root directory of the squashfs filesystem is filled with the
  # closures of the Nix store paths listed here.
  storeContents ? [ ],
  # Pseudo files to be added to squashfs image
  pseudoFiles ? [ ],
  noStrip ? false,
  # Compression parameters.
  # comp ? "xz -Xbcj arm -Xdict-size 100%",
  comp ? "gzip -Xcompression-level 9 -Xstrategy filtered",
}:

let
  pseudoFilesArgs = lib.concatMapStrings (f: ''-p "${f}" '') pseudoFiles;
in
stdenv.mkDerivation {
  name = "${fileName}.squashfs";
  __structuredAttrs = true;

  nativeBuildInputs = [ squashfsTools ];

  buildCommand = ''
    closureInfo=${closureInfo { rootPaths = storeContents; }}

    # Also include a manifest of the closures in a format suitable
    # for nix-store --load-db.
    cp $closureInfo/registration nix-path-registration

    imgPath="$out"

    # Generate the squashfs image.
    mksquashfs nix-path-registration $(cat $closureInfo/store-paths) $imgPath ${pseudoFilesArgs} \
      -no-hardlinks ${lib.optionalString noStrip "-no-strip"} -keep-as-directory -all-root -b 262144 -comp ${comp} \
      -no-exports -no-xattrs -no-fragments -no-recovery -noappend -processors $NIX_BUILD_CORES -root-mode 0755
  '';
}
