{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
{
  options.snowfall = {
    postgres = {
      enable = mkOption {
        type = with types; bool;
        default = true;
        description = "Whether to enable the postgres service";
      };

      type = mkOption {
        type =
          with types;
          enum [
            "master"
            "replica"
          ];
        default = "master";
        description = "Whether this postgres instance is a master or a replica";
      };

      replication = mkOption {
        type = with types; attrsOf types.str;
        default = { };
        description = ''
          Configuration options for setting up replication.
          Example:
          {
            host = "replica-host";
            port = "5432";
            user = "replication-user";
            passwordFile = "/path/to/replication-password-file";
          }
        '';
      };
    };
  };

  config =
    let
      inherit (config.snowfall.postgres)
        enable
        ;
    in
    mkIf enable (mkMerge [
      {
        services.postgresql = {
            enable = true;
        };
      }
    ]);
}
