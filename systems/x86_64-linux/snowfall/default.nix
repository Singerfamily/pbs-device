{ lib, pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];
}
