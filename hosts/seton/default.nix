{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  services = {
    nginx.enable = true;
  };

  boot.initrd.availableKernelModules = [ "mmcblk" "mmc_block" "sdhci_pci" "rtsx_pci_sdmmc" ];

  boot.initrd.kernelModules = [
    "mmcblk"
    "mmc_block"
    "sdhci_pci"
  ];

  # # Since we aren't letting Disko manage fileSystems.*, we need to configure it ourselves
  # # Root partition, is tmpfs because I enabled impermanence.
  # fileSystems."/" = {
  #   device = "tmpfs";
  #   fsType = "tmpfs";
  #   options = ["relatime" "mode=755" "nosuid" "nodev"];
  # };

  # # /nix partition, third partition on the disk image. Since my VPS recognizes
  # # hard drive as "sda", I specify "sda3" here. If your VPS recognizes the drive
  # # differently, change accordingly
  # fileSystems."/nix" = {
  #   device = "/dev/mmcblk0p3";
  #   fsType = "btrfs";
  #   options = ["compress-force=zstd" "nosuid" "nodev"];
  # };

  # # /boot partition, second partition on the disk image. Since my VPS recognizes
  # # hard drive as "sda", I specify "sda2" here. If your VPS recognizes the drive
  # # differently, change accordingly
  # fileSystems."/boot" = {
  #   device = "/dev/sda2";
  #   fsType = "vfat";
  #   options = ["fmask=0077" "dmask=0077"];
  # };
}
