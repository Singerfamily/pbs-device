# INFO: NixOS TPM module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.tpm = {
    # Whether to use TPM2 for secure boot.
    enable = mkOption {
      type = with types; bool;
      default = true;
    };
  };

  config =
    let
      inherit (config.snowfall.tpm) enable;

      users = builtins.attrNames (config.home-manager.users or { });
    in
    mkMerge [
      # TPM2: common options.
      (mkIf enable {
        environment.systemPackages = with pkgs; [
          tpm2-tools
          # tpm-luks-unstable
          # tpm-fido
        ];
        boot.initrd = {
          systemd = {
            enable = true; # For auto unlock
            tpm2.enable = true;
          };
          kernelModules = [ "tpm_crb" ];
          availableKernelModules = [ "tpm_crb" ];
        };

        security.tpm2 = {
          enable = true;
          tctiEnvironment.enable = true;
        };

        users.users = snowfall.mapUsersToGroup {
          group = "tss";
          users = users;
        };
      })
    ];
}
