{ pkgs, ... }:
let
  # execPath = "/home/pbs/selkies";

  # startScript = pkgs.writeShellScript "pbs-video-service" ''
  #   ${pkgs.snowfall.pbs}/bin/pbs start
  #   ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml up -d
  # '';

  # stopScript = pkgs.writeShellScript "pbs-video-service" ''
  #   ${pkgs.docker}/bin/docker compose -f ${execPath}/docker-compose.yml down
  #   ${pkgs.snowfall.pbs}/bin/pbs stop
  # '';
in
{
  # Start the pbs-video systemd service when a V4L device appears
  # and stop it when the device is removed.
  services.udev.extraRules =
    let
      sc = pkgs.systemd; # systemctl path
    in
    ''
      ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video*", TAG+="systemd", ENV{SYSTEMD_WANTS}="pbs-video.service"
      ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video*", RUN+="${sc}/bin/systemctl stop pbs-video.service"
    '';

  environment = {
    systemPackages = with pkgs; [
      snowfall.pbs
    ];
  };

  # Expose a system service so udev (which runs as root) can start/stop it
  systemd.services.pbs = {
    description = "PBS Video Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Start the PBS control tool first, then bring up the docker compose stack
      ExecStart = "${pkgs.snowfall.pbs}/bin/pbs start --title 'Sacrament Meeting' --visibility public";
      ExecStartPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml up -d";

      # Stop docker compose first, then stop the PBS control tool
      ExecStop = "${pkgs.snowfall.pbs}/bin/pbs stop";
      ExecStopPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml down";
      User = "pbs";

      RemainAfterExit = true;
      Type = "oneshot";
      # Restart = "on-failure";
      # RestartSec = "10s";

      # Ensure systemd waits a little for clean shutdowns
      # TimeoutStartSec = "60s";
      # TimeoutStopSec = "60s";
    };
  };
}
