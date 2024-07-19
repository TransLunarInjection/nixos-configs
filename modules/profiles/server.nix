{ config, lib, ... }:
{
  options.lun.profiles.server = lib.mkEnableOption "Enable server profile";
  config = lib.mkIf config.lun.profiles.server {
    hardware.opengl.enable = lib.mkForce false;
    hardware.pulseaudio.enable = lib.mkForce false;
    services.pipewire.enable = lib.mkForce false;
    boot.plymouth.enable = lib.mkForce false;
  };
}
