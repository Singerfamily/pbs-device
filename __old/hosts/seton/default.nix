{ pkgs, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  services.udev.extraRules =
    let
      obsPath = "/home/${username}/obs";
    in
    ''
      ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${pkgs.docker}/bin/docker compose -f ${obsPath}/docker-compose.yml up -d"
      ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${pkgs.docker}/bin/docker compose -f ${obsPath}/docker-compose.yml down"
    '';
}
