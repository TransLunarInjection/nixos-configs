{ config, pkgs, lib, flake-args, ... }:
let
  name = "hisame";
  swap = "/dev/disk/by-partlabel/hisame_swap";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsHddOpts = btrfsOpts ++ [ ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
  waylandEnv = {
    "KWIN_DRM_DEVICES" = "/dev/dri/card2";
  };
in
{
  imports = [
  ];

  config = {
    networking.hostName = "lun-${name}-nixos";
    sconfig.machineId = "63d3399d2f2f65c96848f11d73082aef";
    system.stateVersion = "22.05";

    boot.kernelParams = [
      # disable ACS for root pcie switches that gpus are under
      # and gpus
      # aiming to get pcie p2pdma working
      "pci=pcie_bus_perf,bfsort,realloc,big_root_window,ecrc=on"
      "pcie_ports=native"
      "pcie_port_pm=force"
      "pcie_aspm=force"
      "iommu=off"
      "amd_iommu=off"
      "amdgpu.lockup_timeout=10000,10000,10000,10000"
      #"iommu=merge"
      #"iommu.strict=1"
      # "amd_iommu=pgtbl_v2"

      # Potential workaround for high idle mclk?
      # https://gitlab.freedesktop.org/drm/amd/-/issues/1301#note_629735
      "video=1024x768@60"
      # also https://gitlab.freedesktop.org/drm/amd/-/issues/1403#note_1190209
      # I usually turn on iommu=pt and amd_iommu=force
      # for vm performance
      # but had some instability that might be caused by it

      # List amdgpu param docs
      #   modinfo amdgpu | grep "^parm:"
      # List amdgpu param current values and undocumented params
      #   nix shell pkgs#sysfsutils -c systool -vm amdgpu

      # runpm:PX runtime pm (2 = force enable with BAMACO, 1 = force enable with BACO, 0 = disable, -1 = auto) (int)
      # BAMACO = keeps memory powered up too for faster enter/exit?
      # "snd_hda_intel.enable=0,0,0"
      "amdgpu.runpm=1"
      # "amdgpu.dpm=0"
      "amdgpu.aspm=1"
      # "amdgpu.bapm=0"

      # sched_policy:Scheduling policy (0 = HWS (Default), 1 = HWS without over-subscription, 2 = Non-HWS (Used for debugging only) (int)
      # "amdgpu.sched_policy=2" # maybe workaround GPU driver crash with mixed graphics/compute loads
      # "amdgpu.vm_update_mode=3" # same, maybe workaround
      # "amdgpu.mcbp=1"
      "amdgpu.audio=0" # We never use display audio
      "amdgpu.ppfeaturemask=0xffffffff" # enable all powerplay features
      "amdgpu.gpu_recovery=2" # advanced TDR mode
      # reset_method:GPU reset method (-1 = auto (default), 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco) (int)
      "amdgpu.reset_method=4"

      # hw hwatchdog doesn't work on this platform
      "nmi_watchdog=0"
      "nowatchdog"
      "acpi_no_watchdog"

      # trust tsc, modern AMD platform
      "tsc=nowatchdog"

      # TODO: Move into amdgpu-no-ecc module
      "amdgpu.ras_enable=0"
      # PCIE tinkering
      # "pcie_ports=native"
      # "pci=bfsort,assign-busses,realloc,nocrs"
      # "pcie_aspm=off"
    ];
    boot.plymouth.enable = lib.mkForce false;
    boot.kernelPatches = [
      {
        name = "whoneedstodebuganyway";
        patch = null;
        extraStructuredConfig = with lib.kernel; {
          DRM_FBDEV_EMULATION = lib.mkForce no;
          FB_VGA16 = lib.mkForce no;
          FB_UVESA = lib.mkForce no;
          FB_VESA = lib.mkForce no;
          FB_EFI = lib.mkForce no;
          FB_NVIDIA = lib.mkForce no;
          FB_RADEON = lib.mkForce no;
        };
      }
      {
        name = "idle-fix";
        patch = ./kernel/idle.patch;
      }
      {
        name = "amdgpu-no-ecc";
        patch = ./kernel/amdgpu-no-ecc.patch;
      }
      {
        name = "amdgpu_bo_fence_warn.patch";
        patch = ./kernel/amdgpu_bo_fence_warn.patch;
      }
      # Already applied in drm-misc-fixes
      # {name = "ckonig-_1";patch = ./kernel/ckonig-amdgpu/_1-dont-pipeline.patch;}
      # {name = "ckonig-_2";patch = ./kernel/ckonig-amdgpu/_2-dont-pipeline.patch;}
      # Already applied in drm-misc-fixes
      # Patch series https://lore.kernel.org/all/9514120e-5780-fd49-02ef-9d3f49f7453e@amd.com/
      # {name = "ckonig-1";patch = ./kernel/ckonig-amdgpu/1.patch;}
      { name = "ckonig-2"; patch = ./kernel/ckonig-amdgpu/2.patch; }
      { name = "ckonig-3"; patch = ./kernel/ckonig-amdgpu/3.patch; }
      { name = "ckonig-4"; patch = ./kernel/ckonig-amdgpu/4.patch; }
      { name = "ckonig-5"; patch = ./kernel/ckonig-amdgpu/5.patch; }
      { name = "ckonig-6"; patch = ./kernel/ckonig-amdgpu/6.patch; }
      { name = "ckonig-7"; patch = ./kernel/ckonig-amdgpu/7.patch; }
      { name = "ckonig-8"; patch = ./kernel/ckonig-amdgpu/8.patch; }
      { name = "ckonig-9"; patch = ./kernel/ckonig-amdgpu/9.patch; }
      { name = "ckonig-10"; patch = ./kernel/ckonig-amdgpu/10.patch; }
      { name = "ckonig-11"; patch = ./kernel/ckonig-amdgpu/11.patch; }
      { name = "ckonig-12"; patch = ./kernel/ckonig-amdgpu/12.patch; }
      { name = "ckonig-13"; patch = ./kernel/ckonig-amdgpu/13.patch; }
      # {
      #   name = "amdgpu-force-d3.patch";
      #   patch = ./kernel/amdgpu-force-d3.patch;
      # }
      # {
      #   name = "disable-acs-redir.patch";
      #   patch = ./kernel/disable-acs-redir.patch;
      # }
      # add this patch? https://gitlab.freedesktop.org/drm/amd/-/issues/2080
    ];
    powerManagement.cpuFreqGovernor = "schedutil";
    programs.corectrl = {
      enable = true;
    };
    users.users.lun.extraGroups = [ "corectrl" ];
    environment.variables = waylandEnv;
    environment.sessionVariables = waylandEnv;
    services.udev.extraRules = ''
      ENV{DEVNAME}=="/dev/dri/card2", TAG+="mutter-device-preferred-primary"
      # Remove AMD GPU Audio devices, if present
      # ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x040300", ATTR{remove}="1"
      # This causes critical thermal fails so don't do it ^ :/

      SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{ID_FS_TYPE}="ntfs3"
    '';
    services.xserver.displayManager.defaultSession = "plasmawayland";
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.displayManager.sddm.enable = lib.mkForce false;
    #services.xserver.displayManager.sddm.settings.General.DisplayServer = "wayland";
    #services.xserver.displayManager.sddm.settings.Wayland.CompositorCommand = "${pkgs.weston}/bin/weston --drm-device=card2 --shell=fullscreen-shell.so";


    # boot.kernelModules = [ "nct6775" "zenpower" ];
    # Use zenpower rather than k10temp for CPU temperatures.
    # boot.extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
    boot.blacklistedKernelModules = [
      "sp5100_tco" # watchdog hardware doesn't work
      # "k10temp" # replaced by zenpower
    ];
    services.power-profiles-daemon.enable = true;

    # most important change is tickless kernel
    # boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

    # Example with overridden source for testing 6.1
    boot.kernelPackages =
      let
        kernel = pkgs.linux_latest.override {
          argsOverride = {
            src = flake-args.linux-freedesktop-drm-misc-fixes;
            version = "6.1.0-dmf";
            modDirVersion = "6.1.0-rc2";
            ignoreConfigErrors = true;
          };
          configfile = pkgs.linux_latest.configfile.overrideAttrs {
            ignoreConfigErrors = true;
          };
        };
      in
      pkgs.linuxPackagesFor kernel;

    lun.power-saving.enable = true;
    lun.efi-tools.enable = true;

    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };
    hardware.opengl = {
      package = pkgs.lun.mesa.drivers;
      extraPackages = [
        pkgs.lun.mesa.drivers
        # Seems to perform worse but may be worth trying if ever run into vulkan issues
        # pkgs.amdvlk
      ];
      extraPackages32 = [
        pkgs.pkgsi686Linux.mesa.drivers
      ];
    };

    services.plex = {
      enable = true;
      openFirewall = true;
      dataDir = "/persist/plex/";
    };
    hardware.cpu.amd.updateMicrocode = true;

    users.mutableUsers = false;

    lun.home-assistant.enable = true;
    lun.wg-netns = {
      enable = true;

      privateKey = "/persist/mullvad/priv.key";
      peerPublicKey = "ctROwSybsU4cHsnGidKtbGYWRB2R17PFMMAqEHpsSm0=";
      endpointAddr = "198.54.133.82:51820";
      ip4 = "10.65.206.162/32";
      ip6 = "fc00:bbbb:bbbb:bb01::2:cea1/128";

      isolateServices = [ "transmission" ];
      forwardPorts = [ 9091 ];

      # dns = [ "10.64.0.1" ];
    };

    services.transmission = let downloadBase = "/persist/transmission"; in
      {
        enable = true;
        # group = "nas";

        settings = {
          download-dir = "${downloadBase}/default";
          incomplete-dir = "${downloadBase}/incomplete";

          peer-port = 45982;

          rpc-enabled = true;
          rpc-port = 9091;
          rpc-authentication-required = true;

          rpc-username = "lun";
          rpc-password = "nix-placeholder";

          # Proxied behind nginx.
          rpc-whitelist-enabled = false;
          rpc-whitelist = "127.0.0.1";

          verify-threads = 4;
        };
      };
    networking.firewall = {
      allowedTCPPorts = [ 45982 ];
      allowedUDPPorts = [ 45982 ];
    };

    lun.persistence.enable = true;
    lun.persistence.dirs = [
      "/home"
      "/var/log"
      "/nix"
      "/var/lib/transmission"
    ];
    users.users.${config.services.borgbackup.repos.uknas.user}.home = "/home/borg";
    services.borgbackup.repos = {
      uknas = {
        authorizedKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC46P3Z/EfSiZJ7xtvHWJFWDBfRH76F9EeDsqbNdTgtl1UxlmckzpCKJgZuiCq4HBQQS2D6sFHq/iVGT5mdq+SQOLZMns3gxH+wedW+XgSGScK35GV7eJjK2EASYzGWEdC/6fhARBpsMcE1cGmLckTeuRHoVGhTig/rOxXCPTPYMaTTLszPkw2D04qut4WD8IuKJegClerbyW2MV4kZdP/kIVg7gGB+jivTTtQsubgSdjw5xLS9OTK0X11f7LSpn6CqC03etnTJUe62D5j5dBLtFT55KLIDGPr86oeFnKF7/ykVSAlhmCly19eJGpG3TqZZaHrqBBtQ9iRsvgavmGiz uknas"
        ];
        path = "/mnt/_nas0/borg/uknas";
      };
    };
    services.beesd.filesystems = {
      persist = {
        spec = "PARTLABEL=${name}_persist_2";
        hashTableSizeMB = 256;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "2.0" ];
      };
      scratch = {
        spec = "PARTLABEL=${name}_scratch";
        hashTableSizeMB = 256;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "2.0" ];
      };
    };
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
      "/boot" = lib.mkForce {
        device = "/dev/disk/by-partlabel/${name}_esp_2";
        fsType = "vfat";
        neededForBoot = true;
        options = [ "discard" "noatime" ];
      };
      "/persist" = lib.mkForce {
        device = "/dev/disk/by-partlabel/${name}_persist_2";
        fsType = "btrfs";
        neededForBoot = true;
        options = btrfsSsdOpts ++ [ "subvol=@persist" "nodev" "nosuid" ];
      };
      "/tmp" = {
        fsType = "tmpfs";
        device = "tmpfs";
        neededForBoot = true;
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=32G" ];
      };
      "/mnt/_nas0" = {
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/_nas0";
        neededForBoot = false;
        options = btrfsHddOpts ++ [ "nofail" ];
      };
      "/mnt/scratch" = {
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/hisame_scratch";
        neededForBoot = false;
        options = btrfsSsdOpts ++ [ "nofail" "subvol=@scratch" ];
      };
      "/mnt/bigscratch" = {
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/hisame_bigscratch";
        neededForBoot = false;
        options = btrfsSsdOpts ++ [ "nofail" "subvol=@main" ];
      };
    };
    swapDevices = lib.mkForce [
      { device = swap; }
    ];
    boot.resumeDevice = swap;
  };
}
