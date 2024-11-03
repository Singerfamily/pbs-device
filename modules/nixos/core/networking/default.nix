{ hostname, ...}: {
  imports = [
    ./dns.nix
  ];
  
  networking = {
    networkmanager.enable = true;

    hostName = "${hostname}";
  };
}