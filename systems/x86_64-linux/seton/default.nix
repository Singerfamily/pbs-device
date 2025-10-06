{ pkgs, ... }:
let
  execPath = "/home/pbs/pbs";

  startScript = "${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml up -d";

  stopScript = "${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml down";
in
{
  programs.nix-ld.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${startScript}"
    ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${stopScript}"
  '';

  services = {
    nginx.enable = true;
  };

  services.cage = {
    enable = true;
    user = "pbs";
    program = "${pkgs.firefox}/bin/firefox --kiosk https://youtube.com";
  };

  networking.hostId = "007f0200";

  system.stateVersion = "25.05";
}