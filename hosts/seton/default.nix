{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  services = {
    nginx.enable = true;
  };
}
