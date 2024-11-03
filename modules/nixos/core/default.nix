{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nixd
    binutils
    htop
    nixfmt-rfc-style
    tpm2-tss
    nvtopPackages.full
    usbutils
    ethtool
  ];
}