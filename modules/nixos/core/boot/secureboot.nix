{ config, pkgs, lib, ... }: let 
  # cfg = config.boot.lanzaboote;
in {
  # config = lib.mkIf cfg.enable {
  #   boot = {
  #     loader.systemd-boot.enable = lib.mkForce false;
  #     lanzaboote = {
  #       pkiBundle = "/etc/secureboot";
  #     };
  #   };

  #   environment.systemPackages = with pkgs; [
  #     sbctl  # for key management
  #   ];
  # };
}