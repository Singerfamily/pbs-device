{pkgs, config, lib, ...}: 
let
  cfg = config.program.steam;
in {
  options.program.steam = {
    enable = lib.mkEnableOption "Enable Steam";
    gamescopeSession = lib.mkEnableOption "Enable GameScope session";
    remotePlay = lib.mkEnableOption "Enable Steam Remote Play";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = cfg.remotePlay; # Open ports in the firewall for Steam Remote Play
        protontricks.enable = true;
      };
      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; [
      protonup
      lutris
    ];

  };
}