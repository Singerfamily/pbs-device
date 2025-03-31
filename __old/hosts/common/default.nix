{ inputs, platform, ... }:{
  services = {
    nginx.enable = true;
  };

  # environment.systemPackages = [ inputs.pbs.packages.${platform}.default ];
}
