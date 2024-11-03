{ libx, lib, ... }:
{
  imports =
    (libx.autoImport ./core)
    ++ (libx.autoImport ./apps)
    ++ (libx.autoImport ./desktop)
    ++ (libx.autoImport ./hardware)
    ++ (libx.autoImport ./services)
    ++ (libx.autoImport ./virtualization);

  drivers = {
    # nvidia.enable = true;
    intel.enable = true;
  };
}
