{ pkgs, ... }: {
  programs.nix-ld.enable = true;

  facter.reportPath = ./facter.json;
  
  services.cage = {
    enable = true;
    user = "pbs";
    program = "${pkgs.firefox}/bin/firefox --kiosk https://youtube.com";
  };

  networking.hostId = "929ceeca";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/eac55b68-6cce-49eb-9b9e-f3b15b2daafb";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/EBED-A002";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
    "mmc_block"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  system.stateVersion = "25.05";
}
