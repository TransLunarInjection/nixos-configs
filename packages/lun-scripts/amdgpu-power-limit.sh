#!/bin/bash
set -euo pipefail

watts="${1:-100}"
profile="${2:-2}"
target=$((watts * 1000000))

for card in /sys/class/drm/card[0-9]; do
	path=("$card"/device/hwmon/hwmon*/power1_cap)
	if [ -f "${path[0]}" ]; then
		old_cap=$(cat "${path[0]}")
		echo -e "Card $card \t $old_cap \t -> \t $target"
		echo "$target" | sudo tee "$card"/device/hwmon/hwmon*/power1_cap >/dev/null
		echo manual | sudo tee "$card"/device/power_dpm_force_performance_level >/dev/null
		echo "$profile" | sudo tee "$card"/device/pp_power_profile_mode >/dev/null
	fi
done

sleep 1

for card in /sys/class/drm/card[0-9]; do
	if [ -f "$card/device/pp_power_profile_mode" ]; then
		echo "Card $card pp_power_profile_mode: active mode has *"
		cat "$card/device/pp_power_profile_mode"
	fi

	if [ -f "$card/device/pp_dpm_mclk" ]; then
		echo "Card $card mclks: $(cat "$card/device/pp_dpm_mclk")"
	fi

	if [ -f "$card/device/pp_dpm_fclk" ]; then
		echo "Card $card fclks: $(cat "$card/device/pp_dpm_fclk")"
	fi
done
