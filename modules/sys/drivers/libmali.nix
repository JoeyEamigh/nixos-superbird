{
  stdenv,
  lib,
  fetchFromGitHub,

  meson,
  ninja,
  pkg-config,
  python3,
  libdrm,
  auto-patchelf,
  wayland,
}:
stdenv.mkDerivation {
  pname = "libMali";
  version = "1.10.0";

  depsBuildBuild = [ pkg-config ];
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
    auto-patchelf
  ];
  buildInputs = [
    libdrm
    wayland
  ];

  src = fetchFromGitHub {
    owner = "JoeyEamigh";
    repo = "libmali-superbird";
    rev = "9506656459f6546a5cf1da74c436e39bd045dd3c";
    hash = "sha256-dirrF9h6UdlT6PgR6RkiO4cNh8oUwVNKW66IuMaO/gE=";
  };

  # src = /home/joey/src/libmali-rockchip;
  # src = /home/joey/src/rockchip-linux-libmali;

  mesonFlags = [
    (lib.mesonOption "arch" "aarch64")
    (lib.mesonOption "gpu" "bifrost-g31")
    (lib.mesonOption "version" "r16p0")
    (lib.mesonOption "platform" "gbm")
  ];

  preConfigure = ''
    patchShebangs --build *
  '';

  postFixup = ''
    set -x

    patchelf --add-rpath ${stdenv.cc.cc.lib}/lib $out/lib/*.so
  '';

  meta = {
    description = "libMali and headers";
    platforms = lib.platforms.linux;
  };
}
