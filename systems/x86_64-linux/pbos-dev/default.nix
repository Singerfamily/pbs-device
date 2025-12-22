{ pkgs, ... }:
# let
#   execPath = "/home/pbs/pbs";

#   startScript = "${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml up -d";

#   stopScript = "${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml down";
# in
{
  imports = [
    ./disko.nix
  ];

  programs.nix-ld.enable = true;

  facter.reportPath = ./facter.json;

  services.pbs = {
    title = "TESTING ONLY";

    start.visibility = "unlisted";

    end = {
      visibility = "unlisted";
      delete = true;
    };
  };

  # services.udev.extraRules = ''
  #   ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${startScript}"
  #   ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${stopScript}"
  # '';

  # services = {
  #   nginx.enable = true;
  # };

  # services.cage = {
  #   enable = true;
  #   user = "pbs";
  #   program = "${pkgs.firefox}/bin/firefox --kiosk https://youtube.com";
  # };

  # networking.hostId = "929ceeca";

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
