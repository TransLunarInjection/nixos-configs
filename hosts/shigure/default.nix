{ pkgs, flakeArgs, lib, ... }:
let
  name = "shigure";
  swap = null;
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
in
{
  imports = [
    ./disks.nix
    flakeArgs.disko.nixosModules.disko
    flakeArgs.nixos-cosmic.nixosModules.default
  ];
  config = {
    networking.hostName = "lun-${name}";
    sconfig.machineId = "b94c1b3ac8c675c1d531e44ec65a9d6e";
    system.stateVersion = "24.11";

    boot.loader.systemd-boot.consoleMode = "max";
    console.font = lib.mkForce "ter-v12n";
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

    services.displayManager.cosmic-greeter.enable = true;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.desktopManager.cosmic.enable = true;
    security.pam.services.cosmic-greeter = { };

    services.udev.packages = [ pkgs.i2c-tools ];
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.linuxPackages_latest.cpupower
      pkgs.dmidecode
      pkgs.mergerfs
      pkgs.mergerfs-tools
    ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    lun.efi-tools.enable = true;
    lun.power-saving.enable = true;
    services.nscd.enableNsncd = true;
    networking.firewall.allowedTCPPorts = [ 5000 5001 8000 8080 8081 ];

    boot.plymouth.enable = lib.mkForce false;
    services.power-profiles-daemon.enable = true;
    lun.amd-pstate.enable = true;
    services.xserver.videoDrivers = [ "amdgpu" ];
    lun.ml = {
      enable = true;
      gpus = [ "amd" ];
    };

    hardware.cpu.amd.updateMicrocode = true;
    lun.profiles = {
      personal = true;
      gaming = true;
      wineGaming = false;
    };


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
        persist = opt // { spec = "PARTLABEL=_persist"; };
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
    };
    swapDevices = lib.optionals (swap != null) [{
      device = swap;
    }];
    boot.resumeDevice = if (swap != null) then swap else "";
  };
}
