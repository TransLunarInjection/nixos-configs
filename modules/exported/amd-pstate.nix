{ config, lib, ... }:
let
  cfg = config.lun.amd-pstate;
in
{
  options.lun.amd-pstate = {
    enable = lib.mkEnableOption "Enable amd_pstate and its unit tests";
    mode = lib.mkOption {
      type = lib.types.enum [ "passive" "guided" "active" ];
      description = ''
        mode argument to `amd_pstate` kernel param, default is `passive`
      '';
      # guided as default - allows powerprofilesctl
      default = "guided";
    };
  };
  config = lib.mkIf cfg.enable {
    # If won't load try sudo modprobe amd_pstate dyndbg==pmf shared_mem=1 -v
    # then check dmesg for error
    # $ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
    # amd-pstate

    # If missing _CPC in SBIOS error:
    # amd_pstate:amd_pstate_init: amd_pstate: the _CPC object is not present in SBIOS
    # option can be found here: Advanced > AMD CBS > NBIOS Common Options > SMU Common Options > CPPC > CPPC CTRL set to Enabled
    boot = {
      kernelParams = [
        # "initcall_blacklist=acpi_cpufreq_init" # use amd_pstate instead, needed on <6.1 kernels only
        "amd_pstate=${cfg.mode}" # mode selection required after cpufreq: amd-pstate: add amd-pstate driver parameter for mode selection
      ];
    };

    system.requiredKernelConfig = with config.lib.kernelConfig; [
      (isYes "X86_AMD_PSTATE")
      (isYes "X86_FEATURE_CPPC")
      (isEnabled "X86_AMD_PSTATE_UT")
    ];
  };
}
