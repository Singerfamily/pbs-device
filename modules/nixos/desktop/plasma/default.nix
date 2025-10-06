# INFO: plasma Home-manager module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  # HACK: Here, because importing in flake.nix does not work.
  # imports = with inputs; [ plasma.homeManagerModules.default ];

  options.snowfall.desktop.plasma = {
    enable = mkOption {
      description = "Whether to enable and configure plasma";
      type = with types; bool;
      default = true;
    };
  };

  config =
    let
      inherit (config.snowfall.desktop.plasma)
        enable
        ;
    in
    mkIf enable {
      services = {
        displayManager.sddm = {
          enable = true;
          wayland.enable = true;
          autoNumlock = true;
        };
        desktopManager.plasma6.enable = true;
      };

      # nixpkgs.overlays = [
      #   (final: prev: {

      #     # kdePackages = prev.kdePackages.overrideScope (
      #     #   kfinal: kprev: {
      #     #     extra-cmake-modules = kprev.extra-cmake-modules.overrideAttrs (old: rec {
      #     #       version = "6.16.0-rc1";
      #     #       src = prev.fetchFromGitLab {
      #     #         domain = "invent.kde.org";
      #     #         owner = "frameworks";
      #     #         repo = "extra-cmake-modules";
      #     #         tag = "v${version}";
      #     #         hash = "sha256-pXiTJ+YRz+Q2B55w0BQyEpPixNsyJMyxy3jICrJR0NM=";
      #     #       };
      #     #       patches = [ ];
      #     #     });
      #     #     kconfig = kprev.kconfig.overrideAttrs (old: rec {
      #     #       version = "6.16.0-rc1";
      #     #       src = prev.fetchFromGitLab {
      #     #         domain = "invent.kde.org";
      #     #         owner = "frameworks";
      #     #         repo = "kconfig";
      #     #         tag = "v${version}";
      #     #         hash = "sha256-XSeaXP86y8yX3nSHiRe5l8Ai/R1sMG2bC8uUKHbGCnw=";
      #     #       };
      #     #     });
      #     #   }
      #     # );
      #   })
      # ];

      environment.systemPackages =
        with pkgs;
        [
          aha
          fwupd
          vulkan-tools
          wayland-utils
          pciutils
          freerdp
        ]
        ++ (with pkgs.kdePackages; [
          discover
          kaccounts-integration
          kaccounts-providers
          plasma-browser-integration
          plasma-disks
          kalk
          partitionmanager
          krdc
          krfb
          krdp
          kdePackages.sddm-kcm
        ]);
    };
}
