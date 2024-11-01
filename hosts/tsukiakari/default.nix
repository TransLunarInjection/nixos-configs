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

    hardware.graphics.extraPackages = with pkgs; [
      #amdvlk
      vulkan-loader
    ];

    boot.kernelParams = [
      "pci=pcie_bus_safe,big_root_window,ecrc=on,realloc,big_root_window,pcie_scan_all"
      #"pcie_ports=native" # handle everything in linux even if uefi wants to
      "pcie_port_pm=force" # force pm on even if not wanted by platform
      "pcie_aspm=force" # force link state
      #"quiet"
      #"splash"

      # modinfo amdgpu | grep "^parm:"
      # "amdgpu.gpu_recovery=2" # advanced TDR mode
      # reset_method:GPU reset method (-1 = auto (default), 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco) (int)
      # "amdgpu.reset_method=4"

      # TODO: Move into amdgpu-no-ecc module
      # "amdgpu.ras_enable=0"
      # "amdgpu.ppfeaturemask=0xffffffff" # enable all powerplay features to allow increasing power limit
      # 10s timeout for all operations (otherwise compute defaults to 60s)
      "amdgpu.lockup_timeout=10000,10000,10000,10000"
      "amdgpu.runpm=1112" # 111x = ./amdgpu-boco-force.patch
      "amdgpu.aspm=1"
      "amdgpu.atpx=1"

      # trust tsc, modern AMD platform
      "tsc=nowatchdog,reliable"
      #"iommu=pt"
      "iommu=off" # AMD recommend disabling iommu for ML loads
      #"amd_iommu=pgtbl_v2"
      "amdgpu.send_sigterm=1"
      #"amdgpu.bapm=1"
      #"amdgpu.mes=1"
      #"amdgpu.uni_mes=1"
      #"amdgpu.use_xgmi_p2p=1"
      "amdgpu.pcie_p2p=1"
      # https://gitlab.com/CalcProgrammer1/OpenRGB/-/blob/master/Documentation/KernelParameters.md
      # "acpi_enforce_resources=lax"
      "mem_encrypt=off"

      "retbleed=off"
    ];

    # pkgs.openrgb-with-all-plugins 

    services.udev.packages = [ pkgs.i2c-tools ];
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.linuxPackages_latest.cpupower
      pkgs.dmidecode
      pkgs.mergerfs
      pkgs.mergerfs-tools
    ];
    #boot.kernelModules = [ "i2c-dev" "i2c-piix4" "i2c-smbus" "sp5100-tco" ];
    boot.kernelModules = [ "sp5100-tco" ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    boot.kernelPatches = [
      {
        name = "amdgpu-plimit-override";
        patch = ./amdgpu-plimit-override.patch;
      }
      {
        name = "amdgpu-boco-force";
        patch = ./amdgpu-boco-force.patch;
      }
      {
        name = "lun-cfg";
        patch = null;
        extraConfig = ''
          HSA_AMD y
          PCI_P2PDMA y
          DMABUF_MOVE_NOTIFY y
          HSA_AMD_P2P y
        '';
        # EEPROM_AT24 m
        # EEPROM_AT25 m
        # #SP5100_TCO m
      }
    ];
    lun.efi-tools.enable = true;
    lun.power-saving.enable = true;
    services.nscd.enableNsncd = true;
    networking.firewall.allowedTCPPorts = [ 5000 5001 8000 8080 8081 ];
    programs.nix-ld.enable = true;

    systemd.defaultUnit = lib.mkForce "multi-user.target";
    boot.plymouth.enable = lib.mkForce false;
    services.xserver.autorun = false;
    #services.xserver.displayManager.startx.enable = true;
    #services.displayManager.sddm.enable = lib.mkForce false;
    services.power-profiles-daemon.enable = true;
    lun.amd-pstate.enable = true;
    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };

    hardware.cpu.amd.updateMicrocode = true;


    services.beesd.filesystems = {
      persist = {
        spec = "PARTLABEL=${name}_persist";
        hashTableSizeMB = 256;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "2.0" ];
      };
      mlA = {
        spec = "LABEL=mlA";
        hashTableSizeMB = 256;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "2.0" ];
      };
    };
    # using beesd so don't need to hardlink within store
    # avoids intellij bug where hardlinks make dirwatcher crash
    nix.settings.auto-optimise-store = lib.mkForce false;

    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.emergencyAccess = true;

    users.mutableUsers = false;
    my.home-manager.enabled-users = [ "lun" ];
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
        device = "/dev/disk/by-partlabel/${name}_persist";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=@nix" ] ++ btrfsSsdOpts;
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
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=50G" ];
      };
      "/mnt/ml/A" = {
        neededForBoot = false;
        fsType = "btrfs";
        device = "/dev/disk/by-label/mlA";
        options = [ "nosuid" "nodev" ] ++ btrfsSsdOpts;
      };
      "/vol/ml" = {
        neededForBoot = false;
        fsType = "fuse.mergerfs";
        depends = [ "/mnt/ml/A" ];
        device = "/mnt/ml/*";
        options = [
          "cache.files=partial"
          "category.create=mspmfs"
          "dropcacheonclose=true"
          "fsname=pool"
          "minfreespace=32G"
          "moveonenospc=true"
        ];
      };
    };
    swapDevices = [{
      device = swap;
    }];
    boot.resumeDevice = swap;
  };
}
