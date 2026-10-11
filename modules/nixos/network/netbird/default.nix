{ config, pkgs, ... }: {
  services.netbird.clients.wt0 = {

    # Automatically login to your Netbird network with a setup key
    # This is mostly useful for server computers.
    # For manual setup instructions, see the wiki page section below.
    login = {
      enable = true;

      # Path to a file containing the setup key for your peer
      # NOTE: if your setup key is reusable, make sure it is not copied to the Nix store.
      setupKeyFile = config.sops.secrets."netbird".path;
    };

    # Set this to true if you want the GUI client
    ui.enable = false;

    # This opens ports required for direct connection without a relay
    openFirewall = true;

    # This opens necessary firewall ports in the Netbird client's network interface
    openInternalFirewall = true;
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
