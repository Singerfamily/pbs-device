{ hostname, lib, ...}: {
  imports = [
    ./dns.nix
  ];
  
  networking = {
    networkmanager.enable = true;
    wireless.enable = lib.mkForce false;

    hostName = "${hostname}";
  };
}