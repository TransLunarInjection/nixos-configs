{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.lun.profiles.graphical && config.lun.profiles.personal) {
    xdg.portal = {
      enable = true;
      wlr = {
        enable = true;
      };
    };

    programs.sway = {
      enable = true;
      extraOptions = [ "--unsupported-gpu" ];
      wrapperFeatures = {
        base = true;
        gtk = false;
      };
      extraPackages = with pkgs; [
        swaylock
        swayidle
        xwayland
        wl-clipboard
        mako # notification daemon
        foot # foot is the default terminal in the config
        dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
        wofi
        kanshi # sway monitor settings / autorandr equivalent? https://github.com/RaitoBezarius/nixos-x230/blob/764d2237ab59ded81492b6c76bc29da027e9fdb3/sway.nix example using it
      ];
    };
  };
}
