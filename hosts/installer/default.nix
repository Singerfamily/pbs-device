{
  self,
  lib,
  modulesPath,
  config,
  hostname,
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  nixRev = if self.inputs.nixpkgs ? rev then self.inputs.nixpkgs.shortRev else "dirty";
  selfRev = if self ? rev then self.shortRev else "dirty";

  dependencies = [
    self.nixosConfigurations.${hostname}.config.system.build.toplevel
    self.nixosConfigurations.${hostname}.config.system.build.diskoScript
    self.nixosConfigurations.${hostname}.config.system.build.diskoScript.drvPath
    self.nixosConfigurations.${hostname}.pkgs.stdenv.drvPath
    (self.nixosConfigurations.${hostname}.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
  ] ++ builtins.map (i: i.outPath) (builtins.attrValues self.inputs);

  closureInfo = pkgs.closureInfo { rootPaths = dependencies; };

  script = (
    pkgs.writeShellScriptBin "install-nixos-unattended" ''
      set -eux
      exec ${pkgs.disko}/bin/disko-install --flake "github:singerfamily/pbs-device"
    ''
  );
in
{
  imports = [
    # base profiles
    "${modulesPath}/profiles/base.nix"
    "${modulesPath}/profiles/all-hardware.nix"

    # Let's get it booted in here
    "${modulesPath}/installer/cd-dvd/iso-image.nix"

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  users = {
    mutableUsers = lib.mkForce false;

    users.nixos = {
      isNormalUser = true;
      name = "nixos";
      extraGroups = [
        "wheel"
        "video"
        "audio"
        "networkmanager"
        "tss"
      ];

      initialHasedPassword = "$y$j9T$IJF7cWEJkRH0Q8mSvTKmp/$Jw3pa2JLqBU7/AFD07La3lYN8DUNmK1wqLHBwBYXJW6";
    };
  };

  nix.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # ISO naming.
  isoImage = {
    isoName = "${hostname}-${nixRev}-${selfRev}.iso";

    # EFI + USB bootable
    makeEfiBootable = true;
    makeUsbBootable = true;

    # Other cases
    appendToMenuLabel = " live";
  };

  # Add Memtest86+ to the ISO.
  boot.loader.grub.memtest86.enable = true;

  # An installation media cannot tolerate a host config defined file
  # system layout on a fresh machine, before it has been formatted.
  swapDevices = lib.mkImageMediaOverride [ ];
  fileSystems = lib.mkImageMediaOverride config.lib.isoFileSystems;

  # `self` here is referring to the flake `self`, you may need to pass it using `specialArgs` or define your NixOS installer configuration
  # in the flake.nix itself to get direct access to the `self` flake variable.

  # Now add `closureInfo` to your NixOS installer
  environment = {
    etc."install-closure".source = "${closureInfo}/store-paths";

    systemPackages = [
      pkgs.git
      script
    ];
  };
}
