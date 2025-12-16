# INFO: DNCrypt-proxy2 NixOS module.

{
  config,
  lib,
  ...
}:

with lib;
with builtins;

{
  options.snowfall.net.tailscale = {
    enable = mkOption {
      description = "Whether to connect the device to Tailscale";
      type = with types; bool;
      default = true;
    };

    ACLtags = mkOption {
      description = "What ACL tags to request from the admin panel";
      type = with types; listOf str;
      default = [
        "broadcast"
      ];
    };
  };

  config =
    let
      inherit (config.snowfall.net.tailscale)
        enable
        ACLtags
        ;
    in
    mkIf enable {
      services.tailscale = mkMerge [
        {
          enable = true;
          openFirewall = true;

          extraUpFlags =
            let
              tags = ACLtags |> map (tag: "tag:${tag}") |> concatStringsSep ",";
            in
            [
              # "--operator=${lib.snowfall.user}" # Allows to manage `tailscaled` without `sudo`.
              "--ssh"

              "--client-id '${config.sops.secrets."tailscale/client-id".path}?ephemeral=false&preauthorized=true'"
              "--client-secret '${config.sops.secrets."tailscale/client-secret".path}'"

              "--advertise-tags '${tags}'"

              # NOTE: Changing settings via `tailscale up` (may) require mentioning all non-default flags.
              "--reset"
            ];
        }
      ];

      sops.secrets = {
        "tailscale/client-id" = { };
        "tailscale/client-secret" = { };
      };
    };
}
