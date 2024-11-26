{
  device ? throw "Set this to your disk device, e.g. /dev/nvme0n1",
  ...
}: {
  disko = {
    # Do not let Disko manage fileSystems.* config for NixOS.
    # Reason is that Disko mounts partitions by GPT partition names, which are
    # easily overwritten with tools like fdisk. When you fail to deploy a new
    # config in this case, the old config that comes with the disk image will
    # not boot either.
    enableConfig = true;
    devices.disk = {
      main = {
        inherit device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}


# {
#   device ? throw "Set this to your disk device, e.g. /dev/nvme0n1",
#   pkgs,
#   ...
# }: let
#   keyFile = pkgs.writeText "secret.key" ''supersecret'';
# in {
#   disko.devices = {
#     disk = {
#       main = {
#         inherit device;
#         type = "disk";
#         content = {
#           type = "gpt";
#           partitions = {
#             ESP = {
#               size = "512M";
#               type = "EF00";
#               content = {
#                 type = "filesystem";
#                 format = "vfat";
#                 mountpoint = "/boot";
#                 mountOptions = [
#                   "defaults"
#                 ];
#               };
#             };
#             luks = {
#               size = "100%";
#               content = {
#                 type = "luks";
#                 name = "crypted";
#                 settings = {
#                   allowDiscards = true;
#                   # inherit keyFile;
#                 };
#                 content = {
#                   type = "btrfs";
#                   extraArgs = [ "-f" ];
#                   subvolumes = {
#                     "/root" = {
#                       mountpoint = "/";
#                       mountOptions = [
#                         "compress=zstd"
#                         "noatime"
#                       ];
#                     };
#                     "/home" = {
#                       mountpoint = "/home";
#                       mountOptions = [
#                         "compress=zstd"
#                         "noatime"
#                       ];
#                     };
#                     "/nix" = {
#                       mountpoint = "/nix";
#                       mountOptions = [
#                         "compress=zstd"
#                         "noatime"
#                       ];
#                     };
#                   };
#                 };
#               };
#             };
#           };
#         };
#       };
#     };
#   };
# }
