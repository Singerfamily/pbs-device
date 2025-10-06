{
  inputs = {
    # SECTION: Core inputs.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SECTION: Nix libraries.
    # Nix flake framework.
    snowfall-lib = {
      url = "github:LeaderbotX400/snowfall-lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository - a collection of Nix packages and modules.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter-modules = {
      url = "github:numtide/nixos-facter-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # VSCode server
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Standalone library for the Nix language.
    nix-std.url = "github:chessai/nix-std";

    # Atomic secret provisioning for NixOS.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Persistent state on systems with ephemeral root storage.
    impermanence.url = "github:nix-community/impermanence";

    # Collection of image builders.
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning and formatting using Nix.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SECTION: Hardware.
    # Lanzaboote, UEFI secure boot for NixOS.
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS modules covering hardware quirks.
    hardware.url = "github:nixos/nixos-hardware";
  };

  outputs =
    { ... }@inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = builtins.path {
        path = ./.;
        name = "flake-src";
      };

      # Snowfall Lib configuration.
      snowfall = {
        namespace = "snowfall";
      };

      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = ".bak";
      };

      # Global NixOS modules.
      systems.modules.nixos = with inputs; [
        determinate.nixosModules.default
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        lanzaboote.nixosModules.lanzaboote
        disko.nixosModules.disko
        nixos-facter-modules.nixosModules.facter
      ];

      # Overlays for Nixpkgs.
      overlays = with inputs; [
        nur.overlays.default
      ];

      templates = {
      };

      alias = {
      };

      # NOTE: An example for future self.
      # outputs-builder = channels: {
      #     topology = import inputs.nix-topology {
      #         pkgs = channels.nixpkgs;
      #         modules = [
      #             { inherit (outputs) nixosConfigurations; }
      #         ];
      #     };
      # };
    };
}
