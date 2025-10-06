# INFO: Core NixOS module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.core = {
    enable = mkOption {
      description = "Whether to enable core NixOS options";
      type = types.bool;
      default = true;
    };

    locale = {
      main = mkOption {
        description = "The main system locale";
        type = with types; str;
        default = "en_CA.UTF-8";
      };

      misc = mkOption {
        description = "Other supported locales";
        type = with types; listOf str;
        default = [ "en_US.UTF-8" ];
      };
    };

    timezone = mkOption {
      type = with types; str;
      default = "America/Edmonton";
    };

    use-uutils = mkOption {
      description = "Whether to use the Rust reimpl. of coreutils";
      type = with types; bool;
      default = false;
    };
  };

  config =
    let
      inherit (config.snowfall.core)
        enable
        locale
        timezone
        use-uutils
        ;
    in
    mkIf enable {
      # Set up root's password.
      sops.secrets."passwords/root".neededForUsers = true;
      users = {
        mutableUsers = mkDefault false;
        users.root = {
          hashedPasswordFile = config.sops.secrets."passwords/root".path;
        };
      };

      # Inherit common Nix settings.
      nix = { inherit (lib.snowfall.nix) settings; };

      # Allow running unpatched dynamic binaries on NixOS.
      # See https://github.com/Mic92/nix-ld.
      programs = {
        nix-ld = {
          enable = true;
          # Libraries that automatically become available to all programs.
          # The default set includes common libraries.
          libraries = [ ];
        };

      };

      # Populate /usr/bin/ with symlinks to executables in system's $PATH.
      # This also helps with running unpatched binaries and scripts on NixOS.
      services.envfs.enable = true;

      # Add some core packages.
      environment.systemPackages =
        with pkgs;
        [
          dmidecode # Reads information about your system's hardware from the BIOS.
          file # A program that shows the type of files.
          hddtemp # Tool for displaying hard disk temperature.
          home-manager # Make sure its always there.
          inxi # Full featured CLI system information tool.
          jmtpfs # FUSE filesystem for MTP devices like Android phones.
          pciutils # Tools for working with PCI devices, such as `lspci`.
          smartmontools # Tools for monitoring the health of hard drives.
          usbutils # Tools for working with USB devices, such as `lsusb`.
          wget # Tool for retrieving files using HTTP, HTTPS, and FTP.
        ]
        ++ (if use-uutils then with pkgs; [ uutils-coreutils-noprefix ] else [ ]);

      # Set up the timezone and locale.
      time.timeZone = timezone;
      i18n = {
        defaultLocale = locale.main;
        supportedLocales = [ "${locale.main}/UTF-8" ] ++ (locale.misc |> builtins.map (l: "${l}/UTF-8"));
        extraLocaleSettings = {
          LC_CTYPE = locale.main;
          LC_NUMERIC = locale.main;
          LC_TIME = locale.main;
          LC_COLLATE = locale.main;
          LC_MONETARY = locale.main;
          LC_MESSAGES = locale.main;
          LC_PAPER = locale.main;
          LC_NAME = locale.main;
          LC_ADDRESS = locale.main;
          LC_TELEPHONE = locale.main;
          LC_MEASUREMENT = locale.main;
          LC_IDENTIFICATION = locale.main;
        };
      };

      # Font management.
      fonts = {
        packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.meslo-lg
        ];
        fontconfig = {
          defaultFonts = {
            serif = [ "JetBrainsMono Nerd Font" ];
            sansSerif = [
              "JetBrainsMono Nerd Font"
            ];
            monospace = [ "JetBrainsMono Nerd Font Mono" ];
          };
        };
      };

      # Additional services
      services.locate.enable = true;

      security.sudo.extraConfig = ''
        Defaults env_keep += "EDITOR"
      '';
    };
}
