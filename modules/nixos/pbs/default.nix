{ pkgs, ... }:
let
  execPath = "/home/pbs/selkies";

  startScript = pkgs.writeShellScript "pbs-video-service" ''
    ${pkgs.snowfall.pbs}/bin/pbs start
    ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml up -d
  '';

  stopScript = pkgs.writeShellScript "pbs-video-service" ''
    ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml down
    ${pkgs.snowfall.pbs}/bin/pbs stop
  '';
in
{
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${startScript}"
    ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${stopScript}"
  '';

  environment.systemPackages = with pkgs; [
    snowfall.pbs
  ];
}
