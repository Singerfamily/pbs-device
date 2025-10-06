# INFO: NixOS Bluetooth module.

{
    config,
    lib,
    pkgs,
    ...
}:

with lib; {
  options.snowfall.hardware.bluetooth = {
    # Whether to enable bluetooth support.
    enable = mkOption {
      type = with types; bool;
      default = false;
    };
  };

  config = mkIf config.snowfall.hardware.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    # services.blueman.enable = true;
  };
}