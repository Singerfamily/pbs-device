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

let
  # Get information about the package from Cargo.toml
  meta = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package;
in

pkgs.rustPlatform.buildRustPackage {
  inherit (meta) name version;
  src = builtins.path {
    path = ./.;
  };
  cargoLock.lockFile = ./Cargo.lock;
}
