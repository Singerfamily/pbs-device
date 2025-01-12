{
  pkgs,
  lib,
  modulesPath,
  ...
}:
{

  imports = [
    ./secureboot.nix

    (modulesPath + "/profiles/all-hardware.nix")
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # plymouth.enable = true;
    };

    kernelPackages = lib.mkForce pkgs.linuxPackages;

    initrd = {
      systemd = {
        enable = true; # For auto unlock
        # tpm2 = {
        #   enable = true;
        # };

        emergencyAccess = "$y$j9T$Qcnt3AyroSriQXew5Zb7s/$DGROGy/aZI5JNACimSsnEVGGl/UHK11ZdhUvj3n4uJ9";
      };
      kernelModules = [ "tpm_crb" ];
      availableKernelModules = [ "tpm_crb" ];
    };
  };

  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
}
