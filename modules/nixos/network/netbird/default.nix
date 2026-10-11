{ config, pkgs, ... }: {
  services.netbird.clients.wt0 = {
    openFirewall = true;
    openInternalFirewall = true;
    port = 51820;
  };
}
