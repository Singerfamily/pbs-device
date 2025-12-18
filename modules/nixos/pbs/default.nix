{ pkgs, ... }:
{
  # Start the pbs-video systemd service when a V4L device appears
  # and stop it when the device is removed.

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video*", TAG+="systemd", ENV{SYSTEMD_WANTS}="pbs.service"
    ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video*", RUN+="${pkgs.systemd}/bin/systemctl stop pbs.service"
  '';

  environment = {
    systemPackages = with pkgs; [
      snowfall.yt-cli
    ];
  };

  # Expose a system service so udev (which runs as root) can start/stop it
  systemd.services.pbs-video =
    let
      exe = "${pkgs.snowfall.yt-cli}/bin/yt-cli";
    in
    {
      description = "PBS Video Service";
      after = [ "network.target" ];
      # wantedBy = [ "multi-user.target" ];
      environment = {
        PBS_WORKING_DIR = "/home/pbs/.pbs";
      };
      serviceConfig = {
        # Start the PBS control tool first, then bring up the docker compose stack
        ExecStart = "${exe} start --title 'Sacrament Meeting' --visibility public";
        ExecStartPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml up -d";

        # Stop docker compose first, then stop the PBS control tool
        ExecStop = "${exe} stop";
        ExecStopPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml down";
        User = "pbs";

        StopWhenUnneeded = true;
        RemainAfterExit = true;
        Type = "oneshot";
      };
    };
}
