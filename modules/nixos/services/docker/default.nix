{
  config,
  pkgs,
  lib,
  username,
  ...
}:
let
  cfg = config.virtualisation.docker;
in
{
  config = lib.mkIf cfg.enable {
    # hardware.nvidia-container-toolkit.enable = true;

    users.users.${username}.extraGroups = [ "docker" ];
    virtualisation.docker = {
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      autoPrune.enable = true;
    };

    # Useful other development tools
    # environment.systemPackages = with pkgs; [
    #   distrobox
    #   dive # look into docker image layers
    # ];
  };
}
