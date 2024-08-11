#!/usr/bin/env bash
# Updated for personal use
# Originally from
# https://github.com/tolgaerok/nixos-2405-gnome/blob/7573561d8366650616a165ad29f6c8e6ccce6b18/core/modules/custom-pkgs/cake.nix#L5
# Tolga Erok
# 11-06-2024

if [ "$EUID" -ne 0 ]; then
	exec sudo bash "$0"
fi

apply_cake_qdisc() {
	local interface="$1"
	echo "Configuring interface $interface..."
	# FIXME: hardcoded bw limit because 10gbe nic + 10g rj45 -> 1gbps link reports 10gbe rate
	if tc qdisc replace dev "$interface" root cake bandwidth 900Mbit; then
		echo "Successfully configured CAKE qdisc on $interface."
	else
		echo "Failed to configure CAKE qdisc on $interface."
	fi
}

# Get list of interfaces excluding loopback
interfaces=$(ip link show | awk -F': ' '/state UP/{print $2}')

echo ""
echo "Filtered interfaces: $interfaces"
echo ""

# Apply CAKE qdisc on each interface
for interface in $interfaces; do
	apply_cake_qdisc "$interface" || echo "Failed to apply CAKE to $interface"
done

# Update sysctl.conf if necessary
sysctl_conf="/etc/sysctl.conf"
if ! grep -qxF 'net.core.default_qdisc = cake' "$sysctl_conf"; then
	echo 'net.core.default_qdisc = cake' | tee -a "$sysctl_conf"
	echo "Added net.core.default_qdisc = cake to $sysctl_conf."
	sysctl -p
fi

# Verify qdisc configuration for each interface
for interface in $interfaces; do
	echo "----------------------------------------------"
	echo "Verifying qdisc configuration for $interface: "
	echo "----------------------------------------------"
	if tc qdisc show dev "$interface" | tee /dev/stderr | grep -q 'cake'; then
		echo "CAKE qdisc is active on $interface."
	else
		echo "CAKE qdisc is NOT active on $interface."
	fi
done

sysctl -p
