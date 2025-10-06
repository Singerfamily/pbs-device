{
  config,
  inputs,
  lib,
  ...
}:
{
  # Register flake inputs for nix commands
  nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) (
    lib.filterAttrs (_: lib.isType "flake") inputs
  );

  nix.settings = {
    trusted-users = [
      "root"
      "@wheel"
    ];
    experimental-features = [
      "ca-derivations"
    ];
    system-features = [
      "kvm"
      "big-parallel"
      "nixos-test"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Add inputs to legacy channels
  nix.nixPath = [ "/etc/nix/path" ];

  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/path/${name}";
    value.source = value.flake;
  }) config.nix.registry;

  system.autoUpgrade = {
    enable = true;
    dates = "0 4 * * 0"; # runs weekly on Sunday at 04:00
    flake = "github:singerfamily/nixos";
    allowReboot = true;
  };
}
