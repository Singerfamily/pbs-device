{
  self,
  inputs,
  stateVersion,
  ...
}:

let
  lib = inputs.nixpkgs.lib;

  hostConfiguration = ../hosts;

  modulesDir = ../modules;
  systemModules = (libx.autoImport { path = modulesDir; });

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
    lib.nixosSystem {
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

        # (import "${modulesDir}/core/disko.nix" {
        #   device = disk;
        #   pkgs = inputs.nixpkgs;
        # })

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

  # This function is copied from:
  # https://github.com/yunfachi/nypkgs/blob/master/lib/umport.nix
  #
  # !!! REMOVING THIS NOTICE VIOLATES THE MIT LICENSE OF THE UMPORT PROJECT !!!
  # This notice must be retained in all copies of this function, including modified versions!
  # The MIT License can be found here:
  # https://github.com/yunfachi/nypkgs/blob/master/LICENSE
  autoImport =
    {
      path ? null,
      paths ? [ ],
      include ? [ ],
      exclude ? [ ],
      recursive ? true,
    }:
    with lib;
    with fileset;
    let
      excludedFiles = filter (path: pathIsRegularFile path) exclude;
      excludedDirs = filter (path: pathIsDirectory path) exclude;
      isExcluded =
        path:
        if elem path excludedFiles then
          true
        else
          (filter (excludedDir: lib.path.hasPrefix excludedDir path) excludedDirs) != [ ];
    in
    unique (
      (filter
        (file: pathIsRegularFile file && hasSuffix ".nix" (builtins.toString file) && !isExcluded file)
        (
          concatMap (
            _path:
            if recursive then
              toList _path
            else
              mapAttrsToList (
                name: type: _path + (if type == "directory" then "/${name}/default.nix" else "/${name}")
              ) (builtins.readDir _path)
          ) (unique (if path == null then paths else [ path ] ++ paths))
        )
      )
      ++ (if recursive then concatMap (path: toList path) (unique include) else unique include)
    );

  # ============================ Shell ============================= #

  forAllSystems = lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
