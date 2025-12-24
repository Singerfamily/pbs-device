{
  pkgs,
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
