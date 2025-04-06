{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        # Configure Snowfall Lib, all of these settings are optional.
        snowfall = {
          # Choose a namespace to use for your flake's packages, library,
          # and overlays.
          namespace = "pbs";

          # Add flake metadata that can be processed by tools like Snowfall Frost.
          meta = {
            name = "pbs";
            title = "pbs";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
        ];
      };

      # Add modules to all NixOS systems.
      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko

        
      ];
    };
}
