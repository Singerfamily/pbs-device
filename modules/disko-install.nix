# `self` here is referring to the flake `self`, you may need to pass it using `specialArgs` or define your NixOS installer configuration
# in the flake.nix itself to get direct access to the `self` flake variable.
{
  pkgs,
  self,
  hostname,
  ...
}:
let
  dependencies = [
    self.nixosConfigurations.${hostname}.config.system.build.toplevel
    self.nixosConfigurations.${hostname}.config.system.build.diskoScript
    self.nixosConfigurations.${hostname}.config.system.build.diskoScript.drvPath
    self.nixosConfigurations.${hostname}.pkgs.stdenv.drvPath
    (self.nixosConfigurations.${hostname}.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
  ] ++ builtins.map (i: i.outPath) (builtins.attrValues self.inputs);

  closureInfo = pkgs.closureInfo { rootPaths = dependencies; };
in
# Now add `closureInfo` to your NixOS installer
{
  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "install-nixos-unattended" ''
      set -eux
      # Replace "/dev/disk/by-id/some-disk-id" with your actual disk ID
      exec ${pkgs.disko}/bin/disko-install --flake "${self}#${hostname}" --disk vdb "/dev/disk/by-id/some-disk-id"
    '')
  ];
}
