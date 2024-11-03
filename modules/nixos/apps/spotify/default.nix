{pkgs, lib, config, ...}: 
let
  cfg = config.programs.spotify;
in {

  options.programs.spotify = {
    enable = lib.mkEnableOption "Enable Spotify client";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      spotify
    ];

    networking.firewall = {
      # Spotify Local Discovery
      allowedTCPPorts = [ 57621 ];

      # Google Cast
      allowedUDPPorts = [ 5353 ];
    };
  };
}