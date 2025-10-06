{
  lib,
  ...
}:
{
  programs = {
    firefox = {
      enable = true;

      policies = {
        BlockAboutConfig = true;
        ExtensionSettings =
          with builtins;
          let
            extension = shortId: uuid: {
              name = uuid;
              value = {
                install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                installation_mode = "force_installed";
              };
            };
          in
          lib.mkMerge [
            {
              "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
            }
            (listToAttrs [
              (extension "ublock-origin" "uBlock0@raymondhill.net")
            ])
          ];
      };
    };
  };
}
