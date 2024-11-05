{
  self,
  inputs,
  stateVersion,
  ...
}:

let
  hostConfiguration = "${self}/hosts";

  modulesDir = "${self}/modules";
  systemModules = "${modulesDir}/nixos";

  libx = import ./default.nix { inherit self inputs stateVersion; };
  outputs = inputs.self.outputs;
in
{

  # ========================== Buildables ========================== #

  # Helper function for generating host configs
  mkHost =
    {
      hostname ? "nixos",
      username ? "pbs",
      platform ? "x86_64-linux",
      disk ? "/dev/nvme0n1",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          self
          systemModules
          hostname
          username
          platform
          stateVersion
          libx
          outputs
          disk
          ;
      };

      modules = [
        inputs.home-manager.nixosModules.home-manager

        hostConfiguration

        (import "${modulesDir}/disko.nix" {
          pkgs = inputs.nixpkgs;
          device = disk;
        })

        {
          users.users.${username} = {
            isNormalUser = true;
            initialHashedPassword = "$y$j9T$pFldoDmLYkMOqesV3yEsm/$Bf2f.nstUArIlM.BIEGXTm/fvw0uhfz5RqtoJbN9Z9A";

            extraGroups = [
              "wheel"
              "video"
              "audio"
              "networkmanager"
              "tss"
            ];
          };

        }
      ];
    };

  # =========================== Helpers ============================ #

  filesIn = dir: (map (fname: dir + "/${fname}") (builtins.attrNames (builtins.readDir dir)));

  dirsIn =
    dir: inputs.nixpkgs.lib.filterAttrs (name: value: value == "directory") (builtins.readDir dir);

  fileNameOf = path: (builtins.head (builtins.split "\\." (baseNameOf path)));

  isDir = path: builtins.pathExists (path + "/.");

  autoImport =
    path:
    # check if the path is a directory or a file
    if builtins.pathExists (path + "/.") then
      # it's a directory, so the set of overlays from the directory, ordered lexicographically
      let
        content = builtins.readDir path;
      in
      map (n: import (path + ("/" + n)))
        # only match default.nix files
        (
          builtins.filter (
            n:
            (
              builtins.match "default\\.nix" n != null
              &&
                # ignore Emacs lock files (.#foo.nix)
                builtins.match "\\.#.*" n == null
            )
            || builtins.pathExists (path + ("/" + n + "/default.nix"))
          ) (builtins.attrNames content)
        )
    else
      # it's a file, so the result is the contents of the file itself
      import path;

  # ============================ Shell ============================= #

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
