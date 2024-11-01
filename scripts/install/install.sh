#!/usr/bin/env bash
set -xeuo pipefail
IFS=$'\n'

# edit these fields
PART_PREFIX=amayadori
HOSTNAME="lun-$NAME-nixos"

BOOT_PARTITION=/dev/disk/by-partlabel/'EFI\x20system\x20partition'
PERSIST_PARTITION=/dev/disk/by-label/"$PART_PREFIX"_persist
FLAKE=.#$HOSTNAME

mount -t tmpfs none /mnt

mkdir -p /mnt/{boot,persist}

mount $BOOT_PARTITION /mnt/boot
mount "$PERSIST_PARTITION" -o defaults,ssd,nosuid,nodev,compress=zstd,noatime,subvol=@persist /mnt/persist

mkdir -p /mnt/{boot,persist,home,nix,var/log} /mnt/persist/{home,nix,var/log,etc/ssh,root}

for dir in $(nix eval --raw ".#nixosConfigurations.$HOSTNAME.config.lun.persistence.dirs_for_shell_script"); do
	mkdir -p "/mnt$dir" "/mnt/persist$dir"
	mount -o bind "/mnt/persist$dir" "/mnt$dir" || true
done

mount -o bind /mnt/persist/nix /mnt/nix
mount -o bind /mnt/persist/home /mnt/home
mount -o bind /mnt/persist/var/log /mnt/var/log

# Install nixos:
nix-shell -p utillinux git nixFlakes nixos-install-tools --run "nixos-install --cores 8 --impure --no-root-passwd --root /mnt --flake $FLAKE"
# Install refind efi boot manager
nix-shell -p efibootmgr refind --run "refind-install --root /mnt"
