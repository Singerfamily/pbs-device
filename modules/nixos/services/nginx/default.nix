{
  pkgs,
  hostname,
  lib,
  config,
  ...
}:
let
  cfg = config.services.nginx;

  tls-cert =
    {
      alt ? [ ],
    }:
    (pkgs.runCommand "selfSignedCert" { buildInputs = [ pkgs.openssl ]; } ''
      mkdir -p $out
      openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -days 365 -nodes \
        -keyout $out/cert.key -out $out/cert.crt \
        -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,${
          builtins.concatStringsSep "," ([ "IP:127.0.0.1" ] ++ alt)
        }"
    '');
  cert = tls-cert { alt = [ "DNS:${hostname}" ]; };
in
{
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.nginx = lib.mkIf cfg.enable {
      # Use recommended settings
      recommendedZstdSettings = true;
      # recommendedBrotliSettings = true;
      # recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # other Nginx options
      virtualHosts."${hostname}" = {
        addSSL = true;

        sslCertificate = "${cert}/cert.crt";
        sslCertificateKey = "${cert}/cert.key";

        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3000";
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
}
