{
  pkgs,
  config,
  lib,
  ...
}:

with lib;
{
  options.pbs.sound = {
    enable = mkOption {
      description = "Whether to enable PipeWire sound system";
      type = with types; bool;
      default = true;
    };
  };

  config = mkIf config.pbs.sound.enable {
    security.rtkit.enable = true;
    hardware.alsa.enablePersistence = true;
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      systemWide = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [ alsa-utils ];
  };
}
