{ config, ... }:
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

  # networking.wireguard.interfaces = {
  #   wg0 = {
  #     ips = [
  #       "192.168.4.2/24"
  #     ];
  #     peers = [
  #       {
  #         endpoint = "singerfamily.ca:45620";
  #         publicKey = "WhBNoLCiPWzR6fQ4teN3m7T8IR3eSkD+i6xSBhS2bxo=";
  #         presharedKeyFile = config.sops.secrets."wireguard/pre_shared_key".path;
  #       }
  #     ];
  #     privateKeyFile = config.sops.secrets."wireguard/private_key".path;
  #   };
  # };

  # sops.secrets = {
  #   "wireguard/private_key" = {
  #     sopsFile = ../../../secrets/hosts/pbos-dev.yaml;
  #   };
  #   "wireguard/pre_shared_key" = {
  #     sopsFile = ../../../secrets/hosts/pbos-dev.yaml;
  #   };

  #   "wireguard/peer_public_key" = { };
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
