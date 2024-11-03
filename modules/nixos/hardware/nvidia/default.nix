{ config, pkgs, lib, ... }: 
let 
	cfg = config.drivers.nvidia; 
in {
	options.drivers.nvidia = {
		enable = lib.mkEnableOption "Enable NVIDIA Drivers";
		prime = {
			enable = lib.mkEnableOption "Enable NVIDIA PRIME support";
			intelBusID = lib.mkOption {
				type = lib.types.str;
				default = "PCI:0:2:0";
			};
			nvidiaBusID = lib.mkOption {
				type = lib.types.str;
				default = "PCI:1:0:0";
			};
		};
	};

	config = lib.mkIf cfg.enable {
		
		services.xserver.videoDrivers = [ "nvidia" ];

		hardware = {
			graphics = {
				enable = true;
				enable32Bit = true;
				extraPackages = with pkgs;[ vaapiVdpau nvidia-vaapi-driver intel-media-driver]; 
			};

			nvidia = {
				modesetting.enable = true;
				powerManagement = {
					enable = false;
					finegrained = false;
				};
				open = false;
				nvidiaSettings = true;
				package = config.boot.kernelPackages.nvidiaPackages.production;

				prime = lib.mkIf cfg.prime.enable {
					offload = {
						enable = true;
						enableOffloadCmd = true;
					};

					intelBusId = "${cfg.prime.intelBusID}";
					nvidiaBusId = "${cfg.prime.nvidiaBusID}";
				};
			};
		};
	};
}
