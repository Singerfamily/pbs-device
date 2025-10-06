# INFO: NixOS CUPS module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.hardware.cups = {
    # Whether to enable the CUPS printing service.
    enable = mkOption {
      type = with types; bool;
      default = false;
    };
  };

  config = mkIf config.snowfall.hardware.cups.enable {
    services.printing = {
      enable = true;
      drivers = with pkgs; [ hplipWithPlugin ];

      # WARN: The autodiscovery thing of CUPS is sorta
      # a security nightmare, so stay away from that.
      browsed.enable = false;
    };
  };
}
