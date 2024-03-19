{ config, pkgs, lib, flakeArgs, ... }:
let
  name = "hisame";
  swap = "/dev/disk/by-partlabel/hisame_swap";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
  enableFbDevs = true;
  gpuPatches = false;
  # env = {
  #   # kwin wayland tearing support requires this for now
  #   # https://invent.kde.org/plasma/kwin/-/merge_requests/927
  #   # FIXME: remove once AMS tearing patch goes in
  #   # is already in drm-misc-next, kwin doesn't support it yet
  #   KWIN_DRM_NO_AMS = 1;
  # };
  # openrgb = pkgs.openrgb.overrideAttrs {
  #   src = pkgs.fetchFromGitLab {
  #     owner = "LunaA";
  #     repo = "OpenRGB";
  #     rev = "lunnova/pny-4090-verto";
  #     hash = "sha256-WcBJ1t5UaH9qL0hI3qtJFWFD1kROqwK0ElCRW1p60gQ=";
  #   };
  # };
  env = {
    XDP_COSMIC = lib.getExe pkgs.xdg-desktop-portal-cosmic;
  };
in
{
  config = {
    networking.hostName = "lun-${name}-nixos";
    sconfig.machineId = "63d3399d2f2f65c96848f11d73082aef";
    system.stateVersion = "22.05";

    environment.variables = env;
    environment.sessionVariables = env;

    boot.kernelParams = [
      # force fastest transfer size
      # big_root_window for rebar
      # ecrc=on to force on if not done by platform
      "pci=pcie_bus_perf,big_root_window,ecrc=on"
      "pcie_ports=native" # handle everything in linux even if uefi wants to
      "pcie_port_pm=force" # force pm on even if not wanted by platform
      "pcie_aspm=force" # force link state

      # FIXME: turn back on once arc multigpu doesn't fall over
      # workaround for https://gitlab.freedesktop.org/drm/intel/-/issues/7306
      # "iommo=off"
      # "amd_iommu=off"

      # Potential workaround for high idle mclk?
      # https://gitlab.freedesktop.org/drm/amd/-/issues/1301#note_629735
      # or https://gitlab.freedesktop.org/drm/amd/-/issues/1403#note_1190209
      # FIXME: investigate these options once monitor arrives
      # video="HDMI-A-1:2560x1440R@110D" - should be the mode for the 110Hz 24" 1440p Lenovo - G24qe-20
      # "video=d"
      # "video=DP-13:2560x1440R@165D"
      # #"video=DP-13:2560x1440R@144D"
      # "video=DP-14:3440x1440R@72"
      # #"video=DP-14:3440x1440R@70"
      # "video=DP-14:3440x1440R@60"

      # hw hwatchdog doesn't work on this platform
      "nmi_watchdog=0"
      "nowatchdog"
      "acpi_no_watchdog"

      # trust tsc, modern AMD platform
      "tsc=nowatchdog"
      # I usually turn on iommu=pt and amd_iommu=force
      # for vm performance
      # but had some instability that might be caused by it

      # disable first two intel hda devices
      # "snd_hda_intel.enable=0,0" # need this for index headset so can't turn off!

      # List amdgpu param docs
      #   modinfo amdgpu | grep "^parm:"
      # List amdgpu param current values and undocumented params
      #   nix shell pkgs#sysfsutils -c systool -vm amdgpu

      # 10s timeout for all operations (otherwise compute defaults to 60s)
      "amdgpu.lockup_timeout=10000,10000,10000,10000"
      # runpm:PX runtime pm (2 = force enable with BAMACO, 1 = force enable with BACO, 0 = disable, -1 = auto) (int)
      # BAMACO = keeps memory powered up too for faster enter/exit?
      "amdgpu.runpm=2"
      "amdgpu.aspm=1"
      # "amdgpu.bapm=0"

      # sched_policy:Scheduling policy (0 = HWS (Default), 1 = HWS without over-subscription, 2 = Non-HWS (Used for debugging only) (int)
      # "amdgpu.sched_policy=2" # maybe workaround GPU driver crash with mixed graphics/compute loads
      # "amdgpu.vm_update_mode=3" # same, maybe workaround
      # "amdgpu.mcbp=1"
      #"amdgpu.ppfeaturemask=0xffffffff" # enable all powerplay features
      "amdgpu.gpu_recovery=2" # advanced TDR mode
      # reset_method:GPU reset method (-1 = auto (default), 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco) (int)
      "amdgpu.reset_method=4"

      # TODO: Move into amdgpu-no-ecc module
      "amdgpu.ras_enable=0"

      "video=2560x1440@100"

      # allow intel arc gpu to be used
      "i915.force_probe=*"

      # use nvidia-drm instead of efifb
      "nvidia-drm.fbdev=1"
    ];

    boot.plymouth.enable = lib.mkForce false;
    boot.kernelPatches = (lib.optionals (!enableFbDevs) [
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
    ]) ++ lib.optionals gpuPatches [
      {
        name = "THP";
        patch = null;
        extraStructuredConfig = with lib.kernel; {
          READ_ONLY_THP_FOR_FS = lib.mkForce yes;
        };
      }
      {
        name = "amdgpu-no-ecc";
        patch = ./kernel/amdgpu-no-ecc.patch;
      }
      {
        name = "amdgpu_bo_fence_warn.patch";
        patch = ./kernel/amdgpu_bo_fence_warn.patch;
      }
      {
        name = "log-psp-resume";
        patch = ./kernel/log-psp-resume.patch;
      }
      {
        name = "amdgpu-pm-no-resume";
        patch = ./kernel/amdgpu-pm-no-resume.patch;
      }
      # {
      #   name = "arc-multigpu-buffer-length";
      #   patch = ./kernel/arc-multigpu-buffer-length.patch;
      # }
      # {
      #   name = "amdgpu-force-d3.patch";
      #   patch = ./kernel/amdgpu-force-d3.patch;
      # }
      # {
      #   name = "disable-acs-redir.patch";
      #   patch = ./kernel/disable-acs-redir.patch;
      # }
    ];
    services.hardware.bolt.enable = true;
    # specialisation.gnome.configuration = {
    #   services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
    #   services.xserver.desktopManager.gnome.enable = lib.mkForce true;
    #   xdg.portal.extraPortals = lib.mkForce [
    #     pkgs.xdg-desktop-portal-gnome
    #   ];
    # };
    # specialisation.gnome-nvk.configuration = {
    #   lun.nvk.enable = true;
    #   services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
    #   services.xserver.desktopManager.gnome.enable = lib.mkForce true;
    #   xdg.portal.extraPortals = lib.mkForce [
    #     pkgs.xdg-desktop-portal-gnome
    #   ];
    # };
    services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
    services.desktopManager.plasma6.enable = true;
    system.forbiddenDependenciesRegex = "breeze-qt5";
    specialisation.nvk.configuration = {
      lun.nvk.enable = true;
    };
    specialisation.cosmic.configuration = {
      lun.nvk.enable = true;

      imports = [
        flakeArgs.nixos-cosmic.nixosModules.default
      ];

      services.displayManager.cosmic-greeter.enable = true;
      services.xserver.displayManager.sddm.enable = lib.mkForce false;
      services.desktopManager.cosmic.enable = true;
      security.pam.services.cosmic-greeter = { };
    };
    specialisation.cosmic-nvidia-proprietary.configuration = {
      imports = [
        flakeArgs.nixos-cosmic.nixosModules.default
      ];

      services.displayManager.cosmic-greeter.enable = true;
      services.xserver.displayManager.sddm.enable = lib.mkForce false;
      services.desktopManager.cosmic.enable = true;
      security.pam.services.cosmic-greeter = { };
    };

    # services.hardware.openrgb = {
    #   enable = true;
    #   package = openrgb;
    # };
    # environment.systemPackages = [ openrgb ];

    # lun.gpu-select.card = "card0";
    # specialisation.carddefault.configuration = {
    #   lun.gpu-select.card = lib.mkForce null;
    # };
    # specialisation.card0.configuration = {
    #   lun.gpu-select.card = lib.mkForce "card0";
    # };
    # specialisation.card1.configuration = {
    #   lun.gpu-select.card = lib.mkForce "card1";
    # };
    # specialisation.card2.configuration = {
    #   lun.gpu-select.card = lib.mkForce "card2";
    # };
    # lun.amd-pstate.enable = true;
    # lun.amd-pstate.sharedMem = true;
    # powerManagement.cpuFreqGovernor = "schedutil";
    lun.conservative-governor.enable = true;
    lun.tablet.enable = true;
    lun.profiles = {
      gaming = true;
      wineGaming = true;
    };


    services.resolved = {
      enable = true;
      llmnr = "true";
      dnssec = "false";
      fallbackDns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
    services.nscd.enableNsncd = true;

    services.udev.extraRules = ''
      # make mount work for ntfs devices without specifying -t ntfs3
      SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{ID_FS_TYPE}="ntfs3"
    '';

    # boot.kernelModules = [ "nct6775" "zenpower" ];
    # Use zenpower rather than k10temp for CPU temperatures.
    # boot.extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
    boot.blacklistedKernelModules = [
      # "nouveau"
      "radeon"
      "sp5100_tco" # watchdog hardware doesn't work
      # "k10temp" # replaced by zenpower
    ];
    services.power-profiles-daemon.enable = true;

    # use mainline kernel because we're on very recent hardware
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

    # Example with overridden source for testing 6.1
    # boot.kernelPackages =
    #   let
    #     kernel = pkgs.linux_latest.override {
    #       # stdenv = pkgs.llvmPackages_latest.stdenv; #FIXME: https://github.com/llvm/llvm-project/issues/41896
    #       argsOverride = {
    #         src = flakeArgs.linux-rc;
    #         version = "6.1.0";
    #         modDirVersion = "6.1.0";
    #         ignoreConfigErrors = true;
    #       };
    #       configfile = pkgs.linux_latest.configfile.overrideAttrs {
    #         ignoreConfigErrors = true;
    #       };
    #     };
    #   in
    #   pkgs.linuxPackagesFor kernel;


    lun.power-saving.enable = true;
    lun.efi-tools.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];
    services.xserver.dpi = 96; # force 100% DPI
    # services.xserver.drivers = lib.mkIf (config.lun.gpu-select.card != null) (lib.mkForce [{
    #   name = "modesetting";
    #   display = true;
    #   deviceSection = ''
    #     Option "kmsdev" "/dev/dri/${config.lun.gpu-select.card}"
    #   '';
    # }]);
    lun.gpu-select.enable = true;
    # lun.nvidia-gpu-standalone.enable = true; # enable nvidia gpu kernel modules and opengl/vulkan support only, no x stuff changes
    lun.nvidia-gpu-standalone.delayXWorkaround = true; # enable nvidia gpu kernel modules and opengl/vulkan support only, no x stuff changes
    # Need to use .production driver to match version in some docker containers right now
    # Typically use .beta
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.powerManagement.enable = true;
    # hardware.nvidia.powerManagement.finegrained = true;
    lun.ml = {
      enable = false; # FIXME: rocm https://github.com/NixOS/nixpkgs/issues/203949
      gpus = [ "amd" ];
    };
    hardware.opengl = {
      package = pkgs.lun.mesa.drivers;
      package32 = pkgs.lun.mesa-i686.drivers;
    };

    hardware.cpu.amd.updateMicrocode = true;

    users.mutableUsers = false;

    # debugging: sudo ip -all netns exec wg show
    # if 0b received probably need to refresh info below
    lun.wg-netns = {
      enable = true;

      privateKey = "/persist/mullvad/priv.key";
      peerPublicKey = "c3OgLZw8kh5k3lqACXIiShPGr8xcIfdrUs+qRW9zmk4=";
      endpointAddr = "174.127.113.11:51820";
      ip4 = "10.68.90.202/32";
      ip6 = "fc00:bbbb:bbbb:bb01::5:5ac9/128";

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
    # don't have enough ram for 32j/32c to make sense for all builds
    nix.settings.max-jobs = 5;
    nix.settings.cores = 16;
    nix.settings.max-silent-time = 3600;

    lun.persistence.enable = true;
    lun.persistence.dirs = [
      "/home"
      "/var/log"
      "/nix"
      "/var/lib/transmission"
      "/var/lib/sddm"
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
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=40G" ];
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
