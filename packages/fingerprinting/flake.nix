{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (
          import (inputs.nixpkgs) {
            inherit system;
          }
        );
        lib = pkgs.lib;

        pythonDeps = lib.flatten [
          (with pkgs; [
            python3
            ffmpeg
          ])

          (with pkgs.python3Packages; [
            numpy
            scipy
            librosa
            soundfile
            pydub
            matplotlib
            tqdm
            psycopg
            psycopg-pool
            sounddevice
            python-lsp-server
          ])
        ];
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = pythonDeps;
        };

        default = pkgs.stdenv.mkDerivation {
          pname = "hymn-recognition";
          version = "0.1.0";
          src = ./src;
          buildInputs = pythonDeps;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/bin
            cp -r . $out/
            ln -s $out/hymn_recognition.py $out/bin/hymn_recognition
          '';
        };
      }
    );
}
