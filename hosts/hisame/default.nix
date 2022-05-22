{ config, pkgs, lib, nixos-hardware-modules-path, ... }:
let
  name = "hisame";
  swap = "/dev/disk/by-partlabel/_swap";
in
{
  imports = [
  ];

  config = {
    networking.hostName = "lun-${name}-nixos";
    sconfig.machineId = "63d3399d2f2f65c96848f11d73082aef";
    system.stateVersion = "21.11";

    boot.kernelParams = [
      "mitigations=off"
      "quiet"
      "splash"
    ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_xanmod_latest;

    boot.initrd.kernelModules = [ "amdgpu" ];
    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };
    hardware.opengl = {
      extraPackages = [
        pkgs.libglvnd
        pkgs.mesa.drivers
      ];
      extraPackages32 = [
        pkgs.pkgsi686Linux.mesa.drivers
      ];
    };

    hardware.cpu.amd.updateMicrocode = true;

    users.mutableUsers = false;

    lun.persistence.enable = true;
    lun.persistence.dirs = [
      "/home"
      "/var/log"
      "/nix"
    ];
    fileSystems = {
      "/" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "defaults"
          "size=2G"
          "mode=755"
        ];
      };
      "/boot" = {
        device = "/dev/disk/by-partlabel/_esp";
        fsType = "vfat";
        neededForBoot = true;
        options = [ "discard" "noatime" ];
      };
      "/persist" = {
        device = "/dev/disk/by-partlabel/${name}_persist";
        fsType = "ext4";
        neededForBoot = true;
        options = [ "discard" "noatime" ];
      };
      "/tmp" = {
        fsType = "tmpfs";
        device = "tmpfs";
        neededForBoot = true;
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=32G" ];
      };
    };
    swapDevices = [{
      device = swap;
    }];
    boot.resumeDevice = swap;
  };
}
