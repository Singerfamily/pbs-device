{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.pbs;
in

with lib;
{
  options.services.pbs =
    let
      mkVisibilityOption =
        {
          default,
          description,
        }:
        mkOption {
          type = types.enum [
            "public"
            "private"
            "unlisted"
          ];
          inherit default description;
        };
    in
    {
      title = mkOption {
        type = types.str;
        default = "Sacrament Meeting";
        description = "The title of the PBS stream.";
      };
      start = {
        visibility = mkVisibilityOption {
          default = "public";
          description = "The visibility of the PBS stream.";
        };
      };
      end = {
        visibility = mkVisibilityOption {
          default = "unlisted";
          description = "The visibility of the stream after the broadcast.";
        };
        delete = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to delete the video after ending the stream.";
        };
      };
      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable various debug settings for PBS.";
      };
    };
  # Start the pbs-video systemd service when a V4L device appears
  # and stop it when the device is removed.

  config = {
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video*", TAG+="systemd", ENV{SYSTEMD_WANTS}="pbs.service"
      ACTION=="remove", SUBSYSTEM=="video4linux", KERNEL=="video*", RUN+="${pkgs.systemd}/bin/systemctl stop pbs-video.service"
    '';

    environment.systemPackages = with pkgs; [
      snowfall.yt-cli
    ];

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

          PBS_TITLE = cfg.title;

          PBS_START_VISIBILITY = cfg.start.visibility;
          PBS_STOP_VISIBILITY = cfg.end.visibility;

          PBS_STOP_DELETE = if cfg.end.delete then "true" else "";
        };
        serviceConfig = {
          # Start the PBS control tool first, then bring up the docker compose stack
          ExecStart = "${exe} start --title 'Sacrament Meeting' --visibility public";
          ExecStartPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml up -d";

          # Stop docker compose first, then stop the PBS control tool
          ExecStop = "${exe} stop";
          ExecStopPost = "${pkgs.docker}/bin/docker compose -f /home/pbs/selkies/docker-compose.yml down";
          User = "pbs";

          # StopWhenUnneeded = true;

          RemainAfterExit = true;
          Type = "oneshot";
        };
      };
  };
}
