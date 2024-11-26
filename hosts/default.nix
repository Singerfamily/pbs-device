{
  pkgs,
  lib,
  self,
  systemModules,

  hostname,
  platform,
  stateVersion ? null,
  stateVersionDarwin ? null,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  currentStateVersion = if isDarwin then stateVersionDarwin else stateVersion;
  machineConfigurationPath = "${self}/hosts/${hostname}";
  machineConfigurationPathExist = builtins.pathExists machineConfigurationPath;
in
{
  imports = [
    "${systemModules}"
  ] ++ lib.optional machineConfigurationPathExist machineConfigurationPath;

  facter.reportPath = machineConfigurationPath + "/facter.json";

  # System version
  system.stateVersion = currentStateVersion;
  # HostPlatform
  nixpkgs.hostPlatform = platform;
}
