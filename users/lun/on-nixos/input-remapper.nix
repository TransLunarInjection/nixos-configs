{ pkgs, lib, nixosConfig, ... }:
{
  home.file.".config/autostart/input-remapper-autoload.desktop" = lib.mkIf nixosConfig.sconfig.input-remapper {
    source = "${pkgs.input-remapper}/share/applications/input-remapper-autoload.desktop";
  };
}
