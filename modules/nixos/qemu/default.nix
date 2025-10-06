# INFO: NixOS QEMU/KVM module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.qemu = {
    enable = mkOption {
      description = "Whether to enable QEMU/KVM virtualisation";
      type = with types; bool;
      default = false;
    };
  };

  config = mkIf config.snowfall.qemu.enable {
    virtualisation.libvirtd.enable = true;
    environment.systemPackages = with pkgs; [
      qemu
      virt-manager
    ];
  };
}
