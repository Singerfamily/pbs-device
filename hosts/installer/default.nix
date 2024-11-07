{
  self,
  lib,
  modulesPath,
  config,
  username,
  hostname,
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  nixRev = if self.inputs.nixpkgs ? rev then self.inputs.nixpkgs.shortRev else "dirty";
  selfRev = if self ? rev then self.shortRev else "dirty";
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

  nixpkgs.config.allowBroken = true;

  services.getty.autologinUser = "${username}";

  users.mutableUsers = lib.mkForce false;

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

  # environment.etc."install-closure".source = "${closureInfo}/store-paths";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "install-nixos-unattended" ''
      set -eux
      exec ${pkgs.disko}/bin/disko-install --flake "${self}#pbs"
    '')
  ];
}
