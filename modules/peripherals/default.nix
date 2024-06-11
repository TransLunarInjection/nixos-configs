{ config, pkgs, lib, ... }:
let
  crPackages = lib.optionals pkgs.stdenv.hostPlatform.isx86 [ pkgs.framesh ];
in
{
  config = lib.mkMerge [
    {
      services.fwupd.enable = true;
      hardware.wirelessRegulatoryDatabase = true;
      hardware.enableRedistributableFirmware = true;

      # no USB wakeups
      # see: https://github.com/NixOS/nixpkgs/issues/109048
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="disabled"
      '';
    }

    (lib.mkIf config.lun.profiles.graphical {
      services.xserver.libinput = {
        # Enable touchpad/mouse
        enable = true;
        # Disable mouse accel
        mouse = { accelProfile = "flat"; };
      };

      # use with piper for logitech gaming mouse configuration
      # services.ratbagd.enable = true;
      # udev rule for zsa oryx
      hardware.keyboard.zsa.enable = true;
      # steam controller and index headset, only works on x86_64 as of 202309
      hardware.steam-hardware.enable = lib.mkIf (pkgs.system == "x86_64-linux") true;
      # udev rules for ledger
      hardware.ledger.enable = true;

      # udev rules and package for vial keyboard remapper
      services.udev.packages = [ pkgs.lun.vial.udev-rule-vial-serial ] ++ crPackages;
      environment.systemPackages = [ pkgs.lun.vial pkgs.barrier pkgs.openssl ] ++ crPackages;

      programs.noisetorch.enable = true;
      networking.firewall.allowedTCPPorts = [ 24800 ];
      networking.firewall.allowedUDPPorts = [ 24800 ];

      # FIXME: xone doesn't work with wireless, seems unmaintained?
      # find something better or patch it
      # hardware.xone.enable = true;
    })
  ];
}
