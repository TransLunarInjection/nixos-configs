{ pkgs, config, lib, ... }:
let
  name = "tsukiakari";
  swap = "/dev/disk/by-partlabel/${name}_swap";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
in
{
  config = {
    networking.hostName = "${name}-nixos";
    sconfig.machineId = "b0ba0bde10f87905ffa39b7eba520df0";
    system.stateVersion = "24.05";

    hardware.graphics.extraPackages = with pkgs; [
      #amdvlk
      vulkan-loader
    ];

    boot.loader.systemd-boot.consoleMode = "max";
    # console.font = "ter-v12n";
    # console.packages = [ pkgs.terminus_font ];
    boot.kernelParams = [
      "nosplash"
      #"earlycon=efifb"
      #"console=efifb"
      #"video=simplefb:off"
      "initcall_blacklist=efifb_probe,vesafb_probe,uvesafb_probe"
      "fbcon=font:VGA8x8"
      # "ast.modeset=0"
      #"modprobe.blacklist=ast"
      # "initcall_blacklist=ast_pci_probe,efifb_probe,vesafb_probe,uvesafb_probe"
      #"pci=pcie_bus_perf,big_root_window,pcie_scan_all,ecrc=on,realloc=on"
      #"pcie_ports=native" # handle everything in linux even if uefi wants to
      "pcie_port_pm=force" # force pm on even if not wanted by platform
      "pcie_aspm=force" # force link state

      # modinfo amdgpu | grep "^parm:"
      # "amdgpu.gpu_recovery=2" # advanced TDR mode
      # reset_method:GPU reset method (-1 = auto (default), 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco) (int)
      # "amdgpu.reset_method=4"

      # TODO: Move into amdgpu-no-ecc module
      # "amdgpu.ras_enable=0"
      # "amdgpu.ppfeaturemask=0xffffffff" # enable all powerplay features to allow increasing power limit
      # 10s timeout for all operations (otherwise compute defaults to 60s)
      "amdgpu.lockup_timeout=10000,10000,10000,10000"
      "amdgpu.runpm=0"
      # "amdgpu.noretry=0" # allow XNACK - keep getting page faults :C
      # "amdgpu.runpm=1111" # 111x = ./amdgpu-boco-force.patch
      "amdgpu.aspm=1"
      "amdgpu.dpm=1"
      "amdgpu.atpx=0"

      # trust tsc, modern AMD platform
      "tsc=nowatchdog,reliable"

      # "iommu=off" # AMD recommend disabling iommu for ML loads
      "iommu=pt" # RCCL / NCCL complaining that should be set to pt?
      "amd_iommu=pgtbl_v2"

      "amdgpu.send_sigterm=1"
      #"amdgpu.bapm=1"
      #"amdgpu.mes=1"
      #"amdgpu.uni_mes=1"
      #"amdgpu.use_xgmi_p2p=1"
      "amdgpu.pcie_p2p=1"
      # https://gitlab.com/CalcProgrammer1/OpenRGB/-/blob/master/Documentation/KernelParameters.md
      # "acpi_enforce_resources=lax"
      "mem_encrypt=off"
    ];
    boot.kernel.sysctl = {
      # RCCL recommends this
      # "kernel.numa_balancing" = 0;
    };

    services.udev.packages = [ pkgs.i2c-tools ];
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1a03", ATTR{power/control}="on"
    '';
    environment.systemPackages = [
      pkgs.i2c-tools
      config.boot.kernelPackages.cpupower
      pkgs.dmidecode
      pkgs.mergerfs
      pkgs.mergerfs-tools
      pkgs.lun.switchtec-user
    ];
    #boot.kernelModules = [ "i2c-dev" "i2c-piix4" "i2c-smbus" "sp5100-tco" ];
    boot.kernelModules = [ "sp5100-tco" ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    boot.kernelPatches = [

      # {
      #   name = "amdgpu-pm-no-resume.patch";
      #   patch = ../hisame/kernel/amdgpu-pm-no-resume.patch;
      # }
      {
        name = "log-psp-resume.patch";
        patch = ../hisame/kernel/log-psp-resume.patch;
      }
      # {
      #   name = "disable-acs-redir.patch";
      #   patch = ../hisame/kernel/disable-acs-redir.patch;
      # }
      {
        name = "amdgpu-plimit-override";
        patch = ./amdgpu-plimit-override.patch;
      }
      # {
      #   name = "amdgpu-boco-force";
      #   patch = ./amdgpu-boco-force.patch;
      # }
      # {
      #   name = "ast2500-fb-kickout.patch";
      #   patch = ./ast2500-fb-kickout.patch;
      # }
      {
        name = "lun-cfg";
        patch = null;
        extraConfig = ''
          HSA_AMD y
          PCI_P2PDMA y
          DMABUF_MOVE_NOTIFY y
          HSA_AMD_P2P y
          PCI_SW_SWITCHTEC y
          FONT_TER16x32 n
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
    services.power-profiles-daemon.enable = true;
    lun.amd-pstate.enable = true;
    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };

    hardware.cpu.amd.updateMicrocode = true;


    services.beesd.filesystems =
      let
        opt = {
          hashTableSizeMB = 768;
          # logLevels = { emerg = 0; alert = 1; crit = 2; err = 3; warning = 4; notice = 5; info = 6; debug = 7; };
          verbosity = "info";
          extraOptions = [ "--loadavg-target" "2.0" "--thread-count" "2" ];
        };
      in
      {
        persist = opt // { spec = "PARTLABEL=${name}_persist"; };
        mlA = opt // { spec = "LABEL=mlA"; };
        mlB = opt // { spec = "PARTLABEL=mlB"; };
      };
    # using beesd so don't need to hardlink within store
    # avoids intellij bug where hardlinks make dirwatcher crash
    nix.settings.auto-optimise-store = lib.mkForce false;

    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.emergencyAccess = true;

    users.mutableUsers = false;
    my.home-manager.enabled-users = [ "lun" ];
    lun.persistence.enable = true;
    zramSwap.enable = true;
    zramSwap.memoryPercent = 30;
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
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=96G" ];
      };
      "/mnt/ml/A" = {
        neededForBoot = false;
        fsType = "btrfs";
        device = "/dev/disk/by-label/mlA";
        options = [ "nosuid" "nodev" ] ++ btrfsSsdOpts;
      };
      "/mnt/ml/B" = {
        neededForBoot = false;
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/mlB";
        options = [ "nosuid" "nodev" ] ++ btrfsSsdOpts;
      };
      "/vol/ml" = {
        neededForBoot = false;
        fsType = "fuse.mergerfs";
        depends = [ "/mnt/ml/A" "/mnt/ml/B" ];
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
