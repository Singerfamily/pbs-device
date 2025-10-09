{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # You also have access to your flake's inputs.
  inputs,

  # The namespace used for your flake, defaulting to "internal" if not set.
  namespace,

  # All other arguments come from NixPkgs. You can use `pkgs` to pull packages or helpers
  # programmatically or you may add the named attributes as arguments here.
  pkgs,
  stdenv,
  ...
}:

with pkgs;
stdenv.mkDerivation (finalAttrs: {
  pname = "kasmvnc";
  version = "4.2";

  src = fetchurl {
    url = "https://github.com/kasmtech/KasmVNC/releases/download/v${finalAttrs.version}/kasmvncserver_bookworm_${finalAttrs.version}_amd64.deb";
    hash = "sha256-qE0W4xrf/CzyF4JDtHts0yk/GJWDF/xMLEFU55WfC+g=";
  };

  unpackCmd = "dpkg -x $curSrc source";

  nativeBuildInputs = [
    dpkg
  ];

  buildInputs = [
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mv usr/lib 
    mv usr/share usr/lib usr/bin etc/kasmvnc $out
    # ln -s $out/opt/gfie-${finalAttrs.version}/gfie $out/bin/gfie

    runHook postInstall
  '';
})