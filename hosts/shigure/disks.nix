{ config, ... }:
{
  boot.kernelParams = [ "systemd.log_level=debug" "systemd.log_target=kmsg" "log_buf_len=1M" "printk.devkmsg=on" ];
  boot.initrd =
    {
      systemd.enable = true;
    };

  # nix build .#nixosConfigurations.builder.config.system.build.diskoImages
  disko = {
    enableConfig = false;
    memSize = 8192;

    devices.nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "relatime" "mode=755" "nosuid" "nodev" ];
    };
    devices.disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        imageName = "nixos-${config.networking.hostName}";
        imageSize = "16G";
        content = {
          type = "gpt";

          partitions = {
            # Compared to MBR, GPT partition table doesn't reserve space for MBR
            # boot record. We need to reserve the first 1MB for MBR boot record,
            # so Grub can be installed here.
            # boot = {
            #   alignment = 2048;
            #   size = "1M";
            #   type = "EF02"; # for grub MBR
            #   # Use the highest priority to ensure it's at the beginning
            #   priority = 0;
            # };

            # ESP partition, or "boot" partition as you may call it. In theory,
            # this config will support VPSes with both EFI and BIOS boot modes.
            ESP = {
              alignment = 2048;
              label = "_esp";
              name = "ESP";
              # Reserve 512MB of space per my own need. If you use more/less
              # on your boot partition, adjust accordingly.
              size = "512M";
              type = "EF00";
              # Use the second highest priority so it's before the remaining space
              priority = 1;
              # Format as FAT32
              content = {
                type = "filesystem";
                format = "vfat";
                # Use as boot partition. Disko use the information here to mount
                # partitions on disk image generation. Use the same settings as
                # fileSystems.*
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };

            # Parition to store the NixOS system, use all remaining space.
            persist = {
              alignment = 2048;
              size = "100%";
              label = "_persist";
              # Format as Btrfs. Change per your needs.
              content = {
                type = "btrfs";
                subvolumes =
                  let
                    commonOptions = [
                      "compress=zstd"
                      "noatime"
                      "space_cache=v2"
                    ];
                  in
                  {
                    # nix store
                    "/@nix" = {
                      mountpoint = "/nix";
                      mountOptions = commonOptions;
                    };

                    # Persistent data
                    "/@persist" = {
                      mountpoint = "/persist";
                      mountOptions = commonOptions ++ [
                        "nodev"
                        "nosuid"
                      ];
                    };
                  };
              };
              # content = {
              #   type = "filesystem";
              #   format = "btrfs";
              #   # Use as the Nix partition. Disko use the information here to mount
              #   # partitions on disk image generation. Use the same settings as
              #   # fileSystems.*
              #   mountpoint = "/persist";
              #   mountOptions = [ "compress-force=zstd" "space_cache=v2" "noatime" "nosuid" "nodev" ];
              # };
            };
          };
        };
      };
    };
  };
}
