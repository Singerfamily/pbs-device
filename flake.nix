{
  description = "NixOS Configurations";

  inputs = {
    # Official NixOS repo
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "git+https://github.com/NixOS/nixos-hardware";

    # NixOS community
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-cli.url = "github:water-sucks/nixos";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Just for pretty flake.nix
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    { self, flake-parts, ... }@inputs:
    let
      linuxArch = "x86_64-linux";
      linuxArmArch = "aarch64-linux";
      darwinArch = "aarch64-darwin";
      stateVersion = "24.11";
      libx = import ./lib { inherit self inputs stateVersion; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        linuxArch
        linuxArmArch
        darwinArch
      ];

      flake = {
        nixosConfigurations = {
          # Special Configs
          seton-chapel = libx.mkHost { hostname = "seton-chapel"; };

          # Default Config
          nixos = libx.mkHost { };
        };

        templates = import "${self}/templates" { inherit self; };
      };
    };
}
