#!/usr/bin/env bash
set -xeu

mkdir -p build/image
cd build/image

hn="${1:-builder-nixos}"

if [ "z${2:-}" = "zbuild" ]; then
	rm nixos-"$hn".raw || true
	nix build .#nixosConfigurations."$hn".config.system.build.diskoImagesScript -L
	QEMU_OPTS="-enable-kvm -smp cores=4 -m 8G" ./result --build-memory 8192
	chmod +rw nixos-"$hn".raw
fi

nix build "nixpkgs#legacyPackages.x86_64-linux.OVMF.fd" --no-link
qemu-system-x86_64 -enable-kvm -smp cores=4 -m 8G \
	-machine type=q35 \
	-device usb-ehci -device usb-tablet \
	-device intel-hda -device hda-duplex \
	-device VGA,xres=1280,yres=800 \
	-drive if=pflash,format=raw,readonly=on,file="$(nix eval --raw nixpkgs#OVMF.firmware)" \
	-hda nixos-"$hn".raw
