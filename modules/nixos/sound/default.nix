# INFO: NixOS PipeWire module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.sound = {
    enable = mkOption {
      description = "Whether to enable PipeWire sound system";
      type = with types; bool;
      default = true;
    };
  };

  config = mkIf config.snowfall.sound.enable {
    # security.rtkit.enable = true;

    boot.extraModprobeConfig = ''
      options snd_hda_intel power_save=0
    '';

    hardware.alsa.enable = true;

    # services.pipewire = {
    #   enable = true;
    #   wireplumber.enable = true;
    #   pulse.enable = true;
    #   jack.enable = true;
    #   alsa = {
    #     enable = true;
    #     support32Bit = true;
    #   };
    # };

    # TODO: maybe add `pamixer` for easy volume control.
    environment.systemPackages = with pkgs; [ alsa-utils ];
  };
}
