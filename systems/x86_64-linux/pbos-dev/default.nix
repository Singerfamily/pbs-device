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

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [
        "192.168.4.2/24"
      ];
      peers = [
        {
          allowedIPs = [
            "0.0.0.0/0"
          ];
          endpoint = config.sops.secrets."wireguard/endpoint";
          publicKey = config.sops.secrets."wireguard/peer_public_key";
        }
      ];
      privateKey = config.sops.secrets."wireguard/private_key";
    };
  };

  sops.secrets = {
    "wireguard/private_key" = {
      sopsFile = ../../../secrets/hosts/pbos-dev.yaml;
    };

    "wireguard/peer_public_key" = { };
  };

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
