{ pkgs, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${pkgs.docker}/bin/docker compose -f /home/${username}/obs/docker-compose.yml up -d"
    ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${pkgs.docker}/bin/docker compose -f /home/${username}/obs/docker-compose.yml down"
  '';
}
