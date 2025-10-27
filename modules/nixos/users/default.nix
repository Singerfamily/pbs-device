{
  config,
  lib,
  pkgs,
  ...
}:
let
  users = builtins.attrNames (config.home-manager.users or { });
in
with lib;

{
  options.snowfall.cli = {
    enable = {
      type = types.bool;
      default = false;
      description = "CLI support for Snowfall users";
    };

    users = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "List of users to enable CLI support for Snowfall.";
    };
  };

  config = {
    users.users = mkMerge (
      users
      |> map (username: {
        ${username} = mkMerge [
          {
            hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWHFM4TnBtRI0YPjg3RNkh4axZ6fC/BrchvOh6r5aLj"
            ];

            extraGroups = [
              "video"
              "audio"
              "networkmanager"
              "builders"
            ];
          }
        ];
      })
    );

    sops.secrets = mkMerge (
      users
      |> map (username: {
        "passwords/${username}" = {
          neededForUsers = true;
        };
      })
    );
  };
}
