# INFO: DNCrypt-proxy2 NixOS module.

{
  config,
  lib,
  ...
}:

with lib;
{
  options.snowfall.net.dnscrypt-proxy = {
    enable = mkOption {
      description = "Whether to enable the dnscrypt-proxy2 service";
      type = types.bool;
      default = true;
    };

    settings = mkOption {
      type = types.attrs;
      default = {
        ipv4_servers = true;
        ipv6_servers = true;
        dnscrypt_servers = true;
        doh_servers = true;
        require_dnssec = true;
        require_nolog = true;
        require_nofilter = true;
        block_ipv6 = false;

        timeout = 5000;
        keepalive = 30;
        lb_strategy = "p2";
        lb_estimator = true;
        cache = true;
        force_tcp = false; # No effect if tor is not in use

        bootstrap_resolvers = [
          "1.1.1.1:53"
          "1.0.0.1:53"
        ];
        netprobe_address = "1.1.1.1:53";
        captive_portals.map_file = "/etc/dnscrypt-proxy/captive_portals.txt";

        sources.public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        };

        # You can choose a specific set of servers from https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md
        server_names = [
          "cloudflare"
          "cloudflare-ipv6"
          "cloudflare-security"
          "cloudflare-security-ipv6"
          "adguard-dns-doh"
          "mullvad-adblock-doh"
          "mullvad-doh"
          "nextdns"
          "nextdns-ipv6"
          "quad9-dnscrypt-ipv4-filter-pri"
          "google"
          "google-ipv6"
        ];
      };
    };
  };

  config =
    let
      inherit (config.snowfall.net.dnscrypt-proxy) enable settings;
    in
    mkIf enable {
      services.dnscrypt-proxy = {
        enable = true;
        upstreamDefaults = true;
        inherit settings;
      };
    };
}