{ ... }:

{
  # Scheduled auto upgrade system (this is only for system upgrades, 
  # if you want to upgrade cargo\npm\pip global packages, docker containers or different part of the system 
  # or get really full system upgrade, use `topgrade` CLI utility manually instead.
  # I recommend running `topgrade` once a week or at least once a month)
  system.autoUpgrade = {
    enable = false;
    operation = "switch"; # If you don't want to apply updates immediately, only after rebooting, use `boot` option in this case
    flake = "github:singerfamily/pbs-device";
    flags = [
      "--update-input"
      "nixpkgs"
      "--commit-lock-file"
    ];
    dates = "weekly"; # You can also use `weekly` or `monthly` here
    # channel = "https://nixos.org/channels/nixos-unstable";
  };

}
