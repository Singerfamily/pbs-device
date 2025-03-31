{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  users.users.${username}.extraGroups = [ "docker" ];
  virtualisation.docker = {
    # rootless = {
    #   enable = true;
    #   setSocketVariable = true;
    # };
    autoPrune.enable = true;
  };
}
