{ config, pkgs, ... }: {
  services.netbird.clients.wt0 = {

    # Automatically login to your Netbird network with a setup key
    # This is mostly useful for server computers.
    # For manual setup instructions, see the wiki page section below.
    login.enable = true;

    # Set this to true if you want the GUI client
    ui.enable = false;

    # This opens ports required for direct connection without a relay
    openFirewall = true;

    # This opens necessary firewall ports in the Netbird client's network interface
    openInternalFirewall = true;
  };

  sops.secrets = {
    "netbird" = {
      key = "netbird";
      sopsFile = ../../../../secrets/secrets.yaml;
      owner = "netbird";
    };
  };
}
