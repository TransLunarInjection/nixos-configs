{ config, pkgs, lib, ... }:
let
  nvidia_x11 = config.hardware.nvidia.package;
  cfg = config.lun.nvidia-gpu-standalone;
  module = if cfg.open then nvidia_x11.open else nvidia_x11.bin;
in
{
  options.lun.nvidia-gpu-standalone = {
    enable = lib.mkEnableOption "nvidia kernel modules and acceleration support without touching X configs";
    open = lib.mkEnableOption "using open source driver";
    delayXWorkaround = lib.mkEnableOption "delay X startup to workaround server start failing when KMS is slow to init";
    # TODO: persistenced option
  };
  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "nvidia-uvm" "nvidia" "nvidia_modeset" "nvidia_drm" ];
    boot.kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_DynamicPowerManagement=2"
      "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1"
    ];
    boot.extraModulePackages = [ module ];
    hardware.firmware = [ nvidia_x11.firmware ];
    hardware.graphics.extraPackages = [ nvidia_x11.out ];
    hardware.graphics.extraPackages32 = [ nvidia_x11.lib32 ];
    services.acpid.enable = true;

    # environment.etc."egl/egl_external_platform.d".source = "/run/opengl-driver/share/egl/egl_external_platform.d/";

    services.udev.extraRules = ''
      KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 255'"
      KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d \  -f 4); do mknod -m 666 /dev/nvidia$${i} c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) $${i}; done'"
      KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 254'"
      KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
      KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"
    '';

    systemd.services.display-manager.wants = lib.mkIf cfg.delayXWorkaround [ "systemd-udev-settle.service" ];
    systemd.services.display-manager.serviceConfig.ExecStartPre = lib.mkIf cfg.delayXWorkaround [ "/bin/sh -c 'sleep 1'" ];
  };
}
