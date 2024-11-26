{
  self,
  inputs,
  stateVersion,
  lib ? inputs.nixpkgs.lib,
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
      disk ? throw "Set this to your disk device, e.g. /dev/nvme0n1",
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
        inputs.disko.nixosModules.disko
        # inputs.nixos-facter-modules.nixosModules.facter

        hostConfiguration

        (import "${modulesDir}/disko.nix" {
          device = disk;
          pkgs = inputs.nixpkgs;
        })

        {
          users.users.${username} = {
            isNormalUser = true;
            initialPassword = lib.mkForce "pbs";

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
