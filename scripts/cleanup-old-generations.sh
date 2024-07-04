#!/usr/bin/env bash
if [ ! -f /etc/NIXOS ]; then
	echo "$0 is only for nixos systems"
	echo "If you're on a nixos system make sure you aren't inside an FHS environment shell"
	exit 1
fi

if [ $EUID -ne 0 ]; then
	echo "Please run $0 with sudo"
	exit 1
fi

set -euo pipefail

while IFS= read -r -d '' broken; do
	echo "Removing broken gcroots auto link $broken $(readlink -m "$broken")"
	rm "$broken"
done < <(find /nix/var/nix/gcroots/auto/ -type l -exec test ! -e {} \; -print0)

# Clean up system garbage
nix-collect-garbage --max-freed 1 --delete-older-than 14d

# Clean up current user's garbage if using sudo
if [[ -n "${SUDO_USER:-}" ]]; then
	# Clean up old "result" links and similar from doing dev with nix
	while IFS= read -r -d '' old; do
		target=$(readlink "$old")
		# Unsure if allowing this is a good idea:
		# [[ $target == /nix/var/nix/profiles/per-user/$SUDO_USER/* ]]
		if [[ $target == /home/$SUDO_USER/* ]] || [[ $target == */.cache/nix/* ]]; then
			echo "Removing old auto root $target (from $old)"
			rm "$target"
		else
			echo "Ignoring old auto root $target (from $old) due to unknown location"
		fi
	done < <(find /nix/var/nix/gcroots/auto/ -type l -ctime +60 -mtime +60 -print0)
	sudo -u "$SUDO_USER" nix-collect-garbage --max-freed 1 --delete-older-than 14d
	# I don't care about keeping old home manager gens to swap to at all so wipe them immediately
	if [ -d "/home/$SUDO_USER/.local/state/nix/profiles/home-manager" ]; then
		nix profile wipe-history --profile "/home/$SUDO_USER/.local/state/nix/profiles/home-manager"
	fi
fi

# Switch to current system config. Triggers removing old boot entries for garbage collected generations
/nix/var/nix/profiles/system/bin/switch-to-configuration boot

nix store gc --no-keep-derivations --no-keep-env-derivations
nix store optimise
sync

# We probably just deleted a lot so TRIM all drives
fstrim -av
