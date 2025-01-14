{ config, pkgs, lib, ... }:
let
  crPackages = lib.optionals pkgs.stdenv.hostPlatform.isx86 [ pkgs.framesh ];
in
{
  config = lib.mkMerge [
    {
      # FIXME: causes spurious GPU resumes https://lunnova.dev/articles/linux-gpu-runpm-spurious-resumes/
      # would prefer to enable
      services.fwupd.enable = false;
      hardware.wirelessRegulatoryDatabase = true;
      hardware.enableRedistributableFirmware = true;

      # no USB wakeups
      # see: https://github.com/NixOS/nixpkgs/issues/109048
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="disabled"
      '';
    }

    (lib.mkIf config.lun.profiles.graphical {
      services.libinput = {
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
      services.udev.packages = [
        pkgs.lun.vial.udev-rule-vial-serial
        pkgs.android-udev-rules
        pkgs.libmtp.out
        pkgs.kdePackages.kio-extras
      ] ++ crPackages;
      environment.systemPackages = [
        pkgs.lun.vial
        pkgs.barrier
        pkgs.openssl
        pkgs.jmtpfs
        pkgs.libmtp
        pkgs.kdePackages.kio-extras
        pkgs.kdePackages.kio-admin
      ] ++ crPackages;

      programs.noisetorch.enable = true;
      networking.firewall.allowedTCPPorts = [ 24800 ];
      networking.firewall.allowedUDPPorts = [ 24800 ];

      # FIXME: xone doesn't work with wireless, seems unmaintained?
      # find something better or patch it
      # hardware.xone.enable = true;
    })
  ];
}
