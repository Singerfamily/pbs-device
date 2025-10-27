{ ... }:
{

  networking.firewall = {
    allowedTCPPorts = [
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
        # forceSSL = true;
        # enableACME = true;
        locations = {
          "/" = {
            proxyPass = "https://127.0.0.1:3001";
          };

          "/obs-ws" = {
            proxyPass = "http://127.0.0.1:4455";
            proxyWebsockets = true;
          };
        };
      };
    };
  };
}
