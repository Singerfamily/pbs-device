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

          initialScript = pkgs.writeText "init-sql-script" ''
            # alter user postgres with password 'myPassword';
            CREATE ROLE fingerprints WITH LOGIN PASSWORD 'fingerprints' CREATEDB;
            CREATE DATABASE fingerprints;
            GRANT ALL PRIVILEGES ON DATABASE fingerprints TO fingerprints;
          '';

          # ensureDatabases = [
          #   "fingerprints"
          # ];

          enableTCPIP = true;

          # Same as pg_hba.conf
          authentication = ''
            # TYPE  DATABASE        USER            ADDRESS                 METHOD

            # "local" is for Unix domain socket connections only
            local   all             all                                     trust
            # IPv4 local connections:
            host    all             all             127.0.0.1/32            trust
            # IPv6 local connections:
            host    all             all             ::1/128                 trust
            # Allow replication connections from localhost, by a user with the
            # replication privilege.
            local   replication     all                                     trust
            host    replication     all             127.0.0.1/32            trust
            host    replication     all             ::1/128                 trust

            host all all all scram-sha-256
          '';
        };

        networking.firewall.allowedTCPPorts = [ 5432 ];
      }
    ]);
}
