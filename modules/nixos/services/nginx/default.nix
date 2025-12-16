{ config, ... }:
{

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
      3001 # Selkies Web Interface
    ];

    allowedUDPPorts = [
      4455 # OBS WebSocket
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "0.0.0.0" = {
        addSSL = true;
        # enableACME = true;

        sslCertificate = config.sops.secrets."nginx/public".path;
        sslCertificateKey = config.sops.secrets."nginx/private".path;

        locations = {
          "/" = {
            proxyPass = "https://127.0.0.1:3001";
            proxyWebsockets = true;
          };

          "/obs-ws" = {
            proxyPass = "http://127.0.0.1:4455";
            proxyWebsockets = true;
          };
        };
      };
    };
  };

  sops.secrets = {
    "nginx/public" = {
      key = "certs/nginx/public";
      sopsFile = ../../../../secrets/secrets.yaml;
      owner = "nginx";
    };
    "nginx/private" = {
      key = "certs/nginx/private";
      sopsFile = ../../../../secrets/secrets.yaml;
      owner = "nginx";
    };
  };
}
