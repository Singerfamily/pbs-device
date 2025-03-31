{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.drivers.intel;
in
{
  options.drivers.intel = {
    enable = lib.mkEnableOption "Enable Intel Graphics Drivers";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };

    # OpenGL
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };
}
