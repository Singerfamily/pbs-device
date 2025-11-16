{ pkgs, ... }:
let
  execPath = "/home/pbs/selkies";

  startScript = pkgs.writeShellScript "start-broadcast" ''
    ${pkgs.snowfall.pbs}/bin/pbs start &&
    ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml up -d
  '';

  stopScript = pkgs.writeShellScript "stop-broadcast" ''
    ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml down &&
    ${pkgs.snowfall.pbs}/bin/pbs stop
  '';
in
{
  # Start the pbs-video systemd service when a V4L device appears
  # and stop it when the device is removed.

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${startScript}"
    ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${stopScript}"
  '';

  # services.udev.extraRules =
  #   ''
  #     # ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video*", TAG+="systemd", ENV{SYSTEMD_WANTS}="pbs.service"
  #     # ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video*", RUN+="${pkgs.systemd}/bin/systemctl stop pbs.service"
  #   '';

  environment = {
    variables = {
      PBS_WORKING_DIR = "/home/pbs/.pbs";
    };
    systemPackages = with pkgs; [
      snowfall.pbs
      # startScript
      # stopScript
    ];
  };

  # Expose a system service so udev (which runs as root) can start/stop it
  # systemd.services.pbs = {
  #   description = "PBS Video Service";
  #   after = [ "network.target" ];
  #   # wantedBy = [ "multi-user.target" ];
  #   environment = {
  #     PBS_WORKING_DIR = "/home/pbs/.pbs";
  #   };
  #   serviceConfig = {
  #     # Start the PBS control tool first, then bring up the docker compose stack
  #     ExecStart = "${pkgs.snowfall.pbs}/bin/pbs start --title 'Sacrament Meeting' --visibility public";
  #     ExecStartPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml up -d";

  #     # Stop docker compose first, then stop the PBS control tool
  #     ExecStop = "${pkgs.snowfall.pbs}/bin/pbs stop";
  #     ExecStopPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml down";
  #     User = "pbs";

  #     StopWhenUnneeded = true;
  #     RemainAfterExit = true;
  #     Type = "oneshot";
  #   };
  # };
}
