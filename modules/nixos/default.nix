{ libx, lib, ... }:
{
  imports =
    (libx.autoImport ./core)
    ++ (libx.autoImport ./apps)
    ++ (libx.autoImport ./desktop)
    ++ (libx.autoImport ./hardware)
    ++ (libx.autoImport ./services);

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
