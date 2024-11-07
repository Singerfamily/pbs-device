{ pkgs, ... }: {

  imports = [./secureboot.nix ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # plymouth.enable = true;
    };

    # kernelPackages = pkgs.linuxPackages;

    initrd = {
      systemd = {
        enable = true;  # For auto unlock
        tpm2 = {
          enable = true;
        };
      };
      kernelModules = [ "tpm_crb" ];
      availableKernelModules = ["tpm_crb"];
    };
  };

  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
}
