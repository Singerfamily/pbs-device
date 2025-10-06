# INFO: NixOS GPU module.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  options.snowfall.hardware.gpu = {
    core.enable = mkOption {
      description = "Whether to add common GPU-related modules";
      type = with types; bool;
      default = true;
    };

    intel = {
      enable = mkOption {
        description = "Whether to support Intel graphics";
        type = with types; bool;
        default = true;
      };
      busID = mkOption {
        description = "Intel iGPU PCI bus ID";
        type = with types; nullOr str;
        default = null;
      };
    };

    nvidia = {
      enable = mkOption {
        description = "Whether to support NVIDIA graphics";
        type = with types; bool;
        default = false;
      };
      busID = mkOption {
        description = "NVIDIA dGPU PCI bus ID";
        type = with types; nullOr str;
        default = null;
      };
    };

    amd = {
      enable = mkOption {
        description = "Whether to support AMD graphics";
        type = with types; bool;
        default = false;
      };
      busID = mkOption {
        description = "AMD dGPU PCI bus ID";
        type = with types; nullOr str;
        default = null;
      };
    };
  };

  config =
    let
      inherit (config.snowfall.hardware.gpu)
        core
        intel
        nvidia
        amd
        ;
    in
    mkMerge [
      (mkIf core.enable {
        environment.variables = {
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
        };

        environment.systemPackages = with pkgs; [
          nvtopPackages.full
        ];

        # Exclude `nvtop` from minimal systems.
        # environment.systemPackages =
        #   with pkgs;
        #   (
        #     if
        #       !(builtins.elem config.networking.hostName [
        #       ])
        #     then
        #       [ (nvtopPackages.intel.override { nvidia = nvidia.enable; }) ]
        #     else
        #       [
        #         nvtopPackages.full
        #       ]
        #   );
      })

      (mkIf intel.enable {
        nixpkgs.config.packageOverrides = pkgs: {
          vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        };
        services.xserver.videoDrivers = [
          "intel"
        ];
        hardware = {
          graphics = {
            enable = mkDefault true;
            enable32Bit = mkDefault true;
            extraPackages = with pkgs; [
              intel-media-driver
              vaapiIntel
              vaapiVdpau
              libvdpau-va-gl
            ];
          };
        };
      })

      (mkIf amd.enable {
        services.xserver.videoDrivers = [
          "amdgpu"
        ];

        hardware.graphics = {
          enable = mkDefault true;
          enable32Bit = mkDefault true;
        };

        hardware.amdgpu = {
          initrd.enable = mkDefault true;
          opencl.enable = mkDefault true;
          # amdvlk.enable = mkDefault true;
        };
      })

      (mkIf (nvidia.enable) {
        boot.blacklistedKernelModules = [ "nouveau" ];
        services.xserver.videoDrivers = [ "nvidia" ];

        environment.variables = {
          MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE = "1";
          MESA_LOADER_DRIVER_OVERRIDE = "nvidia";

          LIBVA_DRIVER_NAME = "nvidia";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          NVD_BACKEND = "direct";

          __NV_PRIME_RENDER_OFFLOAD = 1;
          _NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __VK_LAYER_NV_optimus = "NVIDIA_only";

        };

        environment.sessionVariables = {
          VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
        };

        hardware.nvidia =
          let
            nvidiaPackage = config.hardware.nvidia.package;
          in
          {
            package = config.boot.kernelPackages.nvidiaPackages.latest;
            modesetting.enable = true;
            powerManagement = {
              enable = false;
              finegrained = false;
            };
            # enable the open source drivers if the package supports it
            open = lib.mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);

            gsp.enable = true;

            prime = {
              intelBusId = intel.busID;
              nvidiaBusId = nvidia.busID;

              offload = {
                enable = true;
                enableOffloadCmd = true;
              };
            };
          };
      })
    ];
}
