{pkgs, ...}: {
  fonts = {
    enableDefaultPackages = true;
    # packages = with pkgs; [
    #   (nerdfonts.override { fonts = [ 
    #     "FiraCode"
    #     "JetBrainsMono"
    #     "DroidSansMono" 
    #     ]; 
    #   })
    #   corefonts
    # ];

    # fontconfig = {
    #   defaultFonts = {
    #     serif = [  "JetBrainsMono" ];
    #     sansSerif = [ "JetBrainsMono" ];
    #     monospace = [ "JetBrainsMono" ];
    #   };
    # };
  };
}