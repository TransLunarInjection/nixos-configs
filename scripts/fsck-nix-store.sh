#!/usr/bin/env bash
set -x

mount -o remount,rw /nix/store
sudo rm -rf /nix/store/.links/
nix-store --verify --check-contents --repair
nix store gc --no-keep-derivations --no-keep-env-derivations
nix-store --query --referrers-closure "$(find /nix/store -maxdepth 1 -type f -name '*.drv' -size 0)" | xargs nix-store --delete --ignore-liveness
nix-store --gc
nix-store --verify --check-contents --repair
nix store gc

if [ -d /nix/store/.links/ ]; then
	nix store optimise
fi
