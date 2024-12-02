{ lib, config, ... }:
let
  cfg = config.services.pipewire;
in
{
  config = lib.mkIf cfg.enable {
    security.rtkit.enable = lib.mkForce true;
    # hardware = {
    #   pulseaudio = {
    #     enable = true;
    #     systemWide = true;
    #   };
    # };
    hardware.pulseaudio.enable = lib.mkForce false;
    services.pipewire = {
      enable = lib.mkForce true;
      systemWide = true;
      alsa = {
        enable = lib.mkForce true;
        support32Bit = lib.mkForce true;
      };
      pulse.enable = lib.mkForce true;
      jack.enable = lib.mkForce true;
    };
  };
}
