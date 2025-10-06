# INFO: NixOS sops-nix module.

{
  # config,
  lib,
  # system,
  # hostName,
  ...
}:

with lib;
{
  config = {
    sops = {
      defaultSopsFile = mkDefault ../../../secrets/secrets.yaml;
      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # keyFile = "/sops/age/keys.txt";
        # generateKey = true;
      };
    };

    # fileSystems."/etc/ssh".neededForBoot = true; # Impermanence
  };
}
