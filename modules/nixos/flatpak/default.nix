{ config, pkgs, lib, ... }: {
  options.snowfall.flatpak = {
    enable = lib.mkEnableOption "Flatpak support";
  };
  config = lib.mkIf config.snowfall.flatpak.enable {
    services.flatpak.enable = true;
    
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.kdePackages.xdg-desktop-portal-kde];
      config = {
        common = {
          default = [
            "kde"
          ];
        };
      };
    };
  };
}