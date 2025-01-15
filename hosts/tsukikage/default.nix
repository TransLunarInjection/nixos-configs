{ pkgs, flakeArgs, lib, ... }:
let
  name = "tsukikage";
  swap = "/dev/disk/by-partlabel/${name}_swap";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
in
{
  imports = [
    ./disks.nix
    flakeArgs.disko.nixosModules.disko
  ];
  config = {
    networking.hostName = "${name}-nixos";
    sconfig.machineId = "5c1f24e8505861694f34a3778509bf8f";
    system.stateVersion = "24.05";

    hardware.graphics.extraPackages = with pkgs; [
      #amdvlk
      vulkan-loader
    ];

    boot.loader.systemd-boot.consoleMode = "max";
    console.font = "ter-v12n";
    console.packages = [ pkgs.terminus_font ];
    boot.kernelParams = [
      "nosplash"
      "fbcon=font:VGA8x8"
      "pcie_port_pm=force" # force pm on even if not wanted by platform
      "pcie_aspm=force" # force link state
      "tsc=nowatchdog,reliable" # trust tsc, modern AMD platform
      "iommu=off" # AMD recommend disabling iommu for ML loads
      "mem_encrypt=off"
    ];

    services.udev.packages = [ pkgs.i2c-tools ];
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.linuxPackages_latest.cpupower
      pkgs.dmidecode
      pkgs.mergerfs
      pkgs.mergerfs-tools
    ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    # boot.kernelPatches = [];
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
    # services.xserver.videoDrivers = [ "amdgpu" ];
    # lun.ml = {
    #   enable = true;
    #   gpus = [ "amd" ];
    # };

    hardware.cpu.amd.updateMicrocode = true;


    # services.beesd.filesystems =
    #   let
    #     opt = {
    #       hashTableSizeMB = 768;
    #       # logLevels = { emerg = 0; alert = 1; crit = 2; err = 3; warning = 4; notice = 5; info = 6; debug = 7; };
    #       verbosity = "info";
    #       extraOptions = [ "--loadavg-target" "2.0" "--thread-count" "2" ];
    #     };
    #   in
    #   {
    #     persist = opt // { spec = "PARTLABEL=${name}_persist"; };
    #     mlA = opt // { spec = "LABEL=mlA"; };
    #     mlB = opt // { spec = "PARTLABEL=mlB"; };
    #   };
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
        device = "/dev/disk/by-partlabel/_esp";
        fsType = "vfat";
        options = [ "discard" "noatime" ];
      };
      "/persist" = {
        device = "/dev/disk/by-partlabel/_persist";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=@persist" ] ++ btrfsSsdOpts;
      };
      "/nix" = lib.mkForce {
        device = "/dev/disk/by-partlabel/_persist";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=@nix" ] ++ btrfsSsdOpts;
      };
      "/tmp" = {
        fsType = "tmpfs";
        device = "tmpfs";
        neededForBoot = true;
        options = [ "mode=1777" "rw" "nosuid" "nodev" "size=50G" ];
      };
      # "/mnt/ml/A" = {
      #   neededForBoot = false;
      #   fsType = "btrfs";
      #   device = "/dev/disk/by-label/mlA";
      #   options = [ "nosuid" "nodev" ] ++ btrfsSsdOpts;
      # };
      # "/mnt/ml/B" = {
      #   neededForBoot = false;
      #   fsType = "btrfs";
      #   device = "/dev/disk/by-partlabel/mlB";
      #   options = [ "nosuid" "nodev" ] ++ btrfsSsdOpts;
      # };
      # "/vol/ml" = {
      #   neededForBoot = false;
      #   fsType = "fuse.mergerfs";
      #   depends = [ "/mnt/ml/A" "/mnt/ml/B" ];
      #   device = "/mnt/ml/*";
      #   options = [
      #     "cache.files=partial"
      #     "category.create=mspmfs"
      #     "dropcacheonclose=true"
      #     "fsname=pool"
      #     "minfreespace=32G"
      #     "moveonenospc=true"
      #   ];
      # };
    };
    swapDevices = lib.optionals (swap != null) [{
      device = swap;
    }];
    boot.resumeDevice = if (swap != null) then swap else "";
  };
}
