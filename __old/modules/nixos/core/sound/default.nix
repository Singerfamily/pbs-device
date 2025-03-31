{ pkgs, lib, ... }:
{
  security.rtkit.enable = lib.mkForce true;
  # hardware.pulseaudio.enable = lib.mkForce false;
  hardware.alsa.enablePersistence = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    systemWide = lib.mkDefault true;
    alsa = {
      enable = lib.mkDefault true;
      support32Bit = lib.mkDefault true;
    };
    pulse.enable = lib.mkDefault true;
    jack.enable = lib.mkDefault true;
  };

  environment.systemPackages = [ pkgs.alsa-utils ];
}
