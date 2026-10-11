{
  inputs = {
    # SECTION: Core inputs.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable-small.url = "github:nixos/nixpkgs/nixos-unstable-small";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "unstable";
    };

    flake-input-patcher.url = "github:jfly/flake-input-patcher";
  };

  outputs =
    { ... }@inputs:
    let
      patcher = inputs.flake-input-patcher.lib.x86_64-linux;
    in
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
        deploy-rs.overlays.default # or deploy-rs.overlays.default
        (self: super: {
          deploy-rs = {
            inherit (pkgs) deploy-rs;
            lib = super.deploy-rs.lib;
          };
        })
      ];

      patched-inputs = patcher.patch inputs {
        deploy-rs.patches = [ ./patches/deploy-rs-nix-2-33.patch ];
      };

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

      devShells.x86_64-linux.default =
        let
          pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
        in
        pkgs.mkShell {
          packages = [
            inputs.self.patched-inputs.deploy-rs.packages.${pkgs.system}.deploy-rs
          ];
          shellHook = ''alias d="deploy"'';
        };

      deploy.nodes =
        let
          hostnames = builtins.attrNames inputs.self.nixosConfigurations;
        in
        builtins.listToAttrs (
          map (hostname: {
            name = hostname;
            value = {
              hostname = hostname;
              interactiveSudo = false;
              profiles.system = {
                sshUser = "root";
                user = "root";
                path =
                  inputs.deploy-rs.lib.x86_64-linux.activate.nixos
                    inputs.self.nixosConfigurations."${hostname}";
              };
            };
          }) hostnames
        );

      checks = builtins.mapAttrs (
        system: deployLib: deployLib.deployChecks inputs.self.deploy
      ) inputs.deploy-rs.lib;
    };
}
