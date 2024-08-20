{ config, pkgs, lib, ... }:
let
  name = "tsukiakari";
  swap = "/dev/disk/by-partlabel/${name}_swap";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
in
{
  imports = [
  ];

  config = {
    networking.hostName = "${name}-nixos";
    sconfig.machineId = "b0ba0bde10f87905ffa39b7eba520df0";
    system.stateVersion = "24.05";

    boot.kernelParams = [
      "pci=pcie_bus_perf,big_root_window,ecrc=on"
      "pcie_ports=native" # handle everything in linux even if uefi wants to
      "pcie_port_pm=force" # force pm on even if not wanted by platform
      "pcie_aspm=force" # force link state
      "quiet"
      #"splash"
      # "amdgpu.gpu_recovery=2" # advanced TDR mode
      # reset_method:GPU reset method (-1 = auto (default), 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco) (int)
      # "amdgpu.reset_method=4"

      # TODO: Move into amdgpu-no-ecc module
      "amdgpu.ras_enable=0"
      # 10s timeout for all operations (otherwise compute defaults to 60s)
      "amdgpu.lockup_timeout=10000,10000,10000,10000"
      #"amdgpu.runpm=2"
      #"amdgpu.aspm=1"

      # hw hwatchdog doesn't work on this platform
      # "nmi_watchdog=0"
      # "nowatchdog"
      # "acpi_no_watchdog"

      # trust tsc, modern AMD platform
      "tsc=nowatchdog"
      #"iommu=pt"
      "iommu=pt"
      "amd_iommu=pgtbl_v2,force_enable"
      "amdgpu.send_sigterm=1"
      #"amdgpu.bapm=1"
      #"amdgpu.mes=1"
      #"amdgpu.uni_mes=1"
      #"amdgpu.use_xgmi_p2p=1"
      #"amdgpu.pcie_p2p=1"
    ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    boot.kernelPatches = [
      {
        name = "amdgpu-no-ecc";
        patch = ../hisame/kernel/amdgpu-no-ecc.patch;
      }
    ];
    networking.firewall.allowedTCPPorts = [ 5000 5001 8000 8080 8081 ];

    systemd.defaultUnit = lib.mkForce "multi-user.target";
    boot.plymouth.enable = lib.mkForce false;
    services.xserver.autorun = false;
    #services.xserver.displayManager.startx.enable = true;
    #services.displayManager.sddm.enable = lib.mkForce false;
    services.power-profiles-daemon.enable = true;
    lun.amd-pstate.enable = true;
    lun.amd-pstate.sharedMem = true;
    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };

    hardware.cpu.amd.updateMicrocode = true;

    users.mutableUsers = false;
    my.home-manager.enabled-users = [ "lun" "mmk" ];

    lun.persistence.enable = true;
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
        device = "/dev/disk/by-partlabel/${name}_esp";
        fsType = "vfat";
        neededForBoot = true;
        options = [ "discard" "noatime" ];
      };
      "/persist" = {
        device = "/dev/disk/by-partlabel/${name}_persist";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=@persist" ] ++ btrfsSsdOpts;
      };
      "/nix" = {
        device = "/persist/nix";
        noCheck = true;
        fsType = "none";
        neededForBoot = true;
        options = [ "bind" ];
      };
      "/home" = {
        device = "/persist/home";
        noCheck = true;
        neededForBoot = true;
        options = [ "bind" ];
      };
      "/var/log" = {
        device = "/persist/var/log";
        noCheck = true;
        neededForBoot = true;
        options = [ "bind" ];
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
