{ libx, lib, ... }:
{
  drivers = {
    # nvidia.enable = true;
    intel.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  virtualisation.docker.enable = true;
}
