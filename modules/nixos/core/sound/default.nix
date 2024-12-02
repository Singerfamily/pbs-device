{ lib, ... }: {
  security.rtkit.enable = lib.mkForce true;
  hardware.pulseaudio.enable = lib.mkForce false;
  services.pipewire = {
    enable = lib.mkDefault true;
    systemWide = lib.mkDefault true;
    alsa = {
      enable = lib.default true;
      support32Bit = lib.default true;
    };
    pulse.enable = lib.default true;
    jack.enable = lib.default true;
  };
}
