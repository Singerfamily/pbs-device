{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.kernel = {
    type = mkOption {
      type = types.enum [
        "default"
        "zen"
      ];
      default = "default";
      description = "What kind of Linux kernel to use";
    };
  };

  config = mkMerge [
    (mkIf (config.snowfall.kernel.type == "zen") {
      boot.kernelPackages = pkgs.linuxPackages_zen;
    })
  ];
}
