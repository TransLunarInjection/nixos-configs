{ config, pkgs, lib, ... }:
{
  options.lun.profiles.graphical = (lib.mkEnableOption "Enable graphical profile") // { default = true; };
  config = lib.mkIf config.lun.profiles.graphical {
    # DESKTOP ENV
    # Enable the X11 windowing system.
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    programs.ssh.askPassword = "${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass";
    # services.displayManager.sddm.wayland.enable = lib.mkDefault true;
    # services.displayManager.gdm.enable = true;
    # services.displayManager.gdm.wayland = true;
    # services.displayManager.gdm.nvidiaWayland = true;
    environment.systemPackages = lib.mkMerge [
      (lib.mkIf config.services.xserver.desktopManager.plasma5.enable [
        pkgs.sddm-kcm # KDE settings panel for sddm
        pkgs.libsForQt5.bismuth # KDE tiling plugin
      ]
      )
      [
        pkgs.kdePackages.kate
        pkgs.kdePackages.kamera
      ]
    ];
    services.xserver.desktopManager.plasma5.enable = true;
    services.xserver.desktopManager.plasma5.runUsingSystemd = true;
    # vlc is smaller than gstreamer
    services.xserver.desktopManager.plasma5.phononBackend = "vlc";
    services.xserver.windowManager.i3.enable = true;
    services.xserver.windowManager.i3.extraSessionCommands = ''
      systemctl --user import-environment PATH
    '';
    services.displayManager.defaultSession = "none+i3";

    # oom kill faster for more responsiveness
    services.earlyoom.enable = true;

    # PRINT
    # lun.print.enable = true; # FIXME: cups never works right with long uptime / after nixos-rebuild ?

    # XDG
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config.${"none+i3"}.default = [ "kde" "gtk" "*" ];
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
      ];
    };

    # GRAPHICS ACCEL
    hardware.graphics = {
      enable = true;
      enable32Bit = lib.mkForce (pkgs.system == "x86_64-linux");
    };

    # SOUND
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      jack.enable = false;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    hardware.bluetooth.enable = true;

    # BLUETOOTH
    lun.persistence.dirs = [ "/var/lib/bluetooth" ];
    services.blueman.enable = true;
    programs.dconf.enable = true;

    # required for automounting with udiskie
    services.udisks2.enable = true;

    sconfig.yubikey = false; # modules/yubikey # FIXME pam error
  };
}
