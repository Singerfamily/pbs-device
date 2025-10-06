{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import (inputs.nixpkgs) { inherit system; });

      in
      {
        devShell =
          (pkgs.buildFHSEnv {
            name = "deno-env";
            targetPkgs =
              pkgs:
              (with pkgs; [
                udev
                alsa-lib
                deno
                obs-studio
              ]);
            multiPkgs =
              pkgs:
              (with pkgs; [
                udev
                alsa-lib
              ]);
            runScript = "zsh";
          }).env;

        # devShell = pkgs.mkShell {
        #   nativeBuildInputs = with pkgs; [
        #     udev
        #     systemd

        #   ];
        #   buildInputs = with pkgs; [
        #     udev
        #     deno
        #     obs-studio
        #     nodePackages.node-gyp-build
        #   ];
        # };

        # cli = (
        #   pkgs.runCommand "pbs-deno-compile"
        #     {
        #       buildInputs = [ pkgs.deno ];
        #     }
        #     ''
        #       mkdir -p $out/app
        #       cp -r ${./cli}/* $out/app/
        #       cp ${./deno.json} $out/app/
        #       cp ${./deno.lock} $out/app/
        #       cd $out/app
        #       deno compile \
        #         --allow-net \
        #         --allow-read \
        #         --allow-env \
        #         --allow-run \
        #         --allow-sys \
        #         --allow-write \
        #         --unstable-temporal \
        #         --unstable-kv \
        #         --output bin/pbs \
        #         main.ts
        #     ''
        # );

        # cli = pkgs.dockerTools.buildImage {
        #   name = "pbs-deno";
        #   tag = "2.3.5";
        #   fromImage = "denoland/deno:2.3.5";
        #   copyToRoot = pkgs.buildEnv {
        #     name = "pbs-deno-root";
        #     paths = [

        #     ];
        #   };
        # };

        # obs = pkgs.dockerTools.buildLayeredImage {
        #   name = "pbs-device";
        #   tag = "latest";
        #   fromImage = "ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm";
        #   contents = [
        #     pkgs.vlc
        #     pkgs.ffmpeg
        #     pkgs.v4l2loopback
        #     pkgs.v4l_utils
        #     pkgs.pulseaudio
        #     pkgs.pulseaudio-utils
        #     pkgs.konsole
        #     pkgs.obs-studio
        #     pkgs.dolphin
        #     pkgs.wget
        #   ];
        #   extraCommands = ''
        #     # Install tailscale
        #     ${pkgs.curl}/bin/curl -fsSL https://tailscale.com/install.sh | sh

        #     # Copy obs scripts
        #     mkdir -p /scripts
        #     cp -r ${./obs/scripts}/* /scripts/

        #     # Copy /root (if you have files to copy)
        #     cp -r ${./root}/* /root/

        #     # Copy compiled pbs binary from deno image
        #     mkdir -p /usr/bin
        #     cp ${self.cli}/app/bin/pbs /usr/bin/pbs
        #   '';
        # };

        # default = self.obs;

        docker = pkgs.dockerTools.buildImage {
          name = "hello-docker";
          tag = "latest";
          config = {
            Cmd = [ "${pkgs.hello}/bin/hello" ];
          };
        };

      }
    );
}
