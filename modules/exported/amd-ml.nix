{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.lun.amd-ml;
in
{
  options.lun.amd-ml = {
    enable = mkEnableOption "AMD ML-specific optimizations";

    opinionatedDefaults = mkOption {
      type = types.bool;
      default = true;
      description = "Enable opinionated default settings";
    };

    disableEcc = mkOption {
      type = types.bool;
      default = false;
      description = "Disable ECC";
    };

    kernelParams = mkOption {
      type = types.submodule {
        options = {
          pcie = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = ''
              Enable PCIe optimizations. When set to true, this option adds the following kernel parameters:
              - "pci=pcie_bus_perf,big_root_window,ecrc=on": Optimizes PCIe bus performance, increases root window size, and enables end-to-end CRC.
              - "pcie_ports=native": Handles everything in Linux even if UEFI wants to manage it.
              - "pcie_port_pm=force": Forces power management on even if not wanted by the platform.
              - "pcie_aspm=force": Forces Active State Power Management (ASPM) link state.
              These parameters aim to improve PCIe performance and power management for AMD GPUs.
            '';
          };
          amdgpu = mkOption {
            type = types.submodule {
              options = {
                gpuRecovery = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "GPU recovery mode (null to disable)";
                };
                resetMethod = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "GPU reset method (-1 = auto, 0 = legacy, 1 = mode0, 2 = mode1, 3 = mode2, 4 = baco/bamaco)";
                };
                rasEnable = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable RAS (Reliability, Availability, and Serviceability)";
                };
                lockupTimeout = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Lockup timeout in milliseconds (null to use default)";
                };
                runpm = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Runtime power management (null to use default)";
                };
                aspm = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Active State Power Management (null to use default)";
                };
                sendSigterm = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Send SIGTERM on GPU reset";
                };
                bapm = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable Bidirectional Application Power Management";
                };
                mes = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable Memory Encryption Support";
                };
                uniMes = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable Unified Memory Encryption Support";
                };
                xgmiP2p = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable XGMI P2P support";
                };
                pcieP2p = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable PCIe P2P support";
                };
              };
            };
            default = { };
            description = "AMDGPU-specific kernel parameters";
          };
          iommu = mkOption {
            type = types.nullOr (types.enum [ "off" "pt" "on" ]);
            default = null;
            description = "IOMMU mode (off, pt for passthrough, or on)";
          };
        };
      };
      default = { };
      description = "Kernel parameters for AMD ML optimizations";
    };

    useLatestKernel = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Use the latest kernel packages";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.opinionatedDefaults {
      lun.amd-ml.kernelParams = {
        pcie = mkDefault true;
        amdgpu = {
          rasEnable = mkDefault false;
          lockupTimeout = mkDefault 10000;
          sendSigterm = mkDefault true;
          runpm = mkDefault 2;
          aspm = mkDefault 1;
        };
        iommu = mkDefault "pt";
      };
      lun.amd-ml.useLatestKernel = mkDefault true;
    })

    (mkIf cfg.disableEcc {
      lun.amd-ml.kernelParams.ras_enable = false;

      # boot.kernelPatches = [
      #   {
      #     name = "amdgpu-no-ecc";
      #     patch = ./amdgpu-no-ecc.patch;
      #   }
      # ];
    })

    {
      boot.kernelParams =
        (optionals cfg.kernelParams.pcie [
          "pci=pcie_bus_perf,big_root_window,ecrc=on"
          "pcie_ports=native"
          "pcie_port_pm=force"
          "pcie_aspm=force"
        ]) ++
        (optional (cfg.kernelParams.amdgpu.gpuRecovery != null) "amdgpu.gpu_recovery=${toString cfg.kernelParams.amdgpu.gpuRecovery}") ++
        (optional (cfg.kernelParams.amdgpu.resetMethod != null) "amdgpu.reset_method=${toString cfg.kernelParams.amdgpu.resetMethod}") ++
        (optional (!cfg.kernelParams.amdgpu.rasEnable) "amdgpu.ras_enable=0") ++
        (optional (cfg.kernelParams.amdgpu.lockupTimeout != null) "amdgpu.lockup_timeout=${toString cfg.kernelParams.amdgpu.lockupTimeout},${toString cfg.kernelParams.amdgpu.lockupTimeout},${toString cfg.kernelParams.amdgpu.lockupTimeout},${toString cfg.kernelParams.amdgpu.lockupTimeout}") ++
        (optional (cfg.kernelParams.amdgpu.runpm != null) "amdgpu.runpm=${toString cfg.kernelParams.amdgpu.runpm}") ++
        (optional (cfg.kernelParams.amdgpu.aspm != null) "amdgpu.aspm=${toString cfg.kernelParams.amdgpu.aspm}") ++
        (optional (cfg.kernelParams.iommu != null) "iommu=${cfg.kernelParams.iommu}") ++
        [ "amd_iommu=pgtbl_v2,force_enable" ] ++
        (optional cfg.kernelParams.amdgpu.sendSigterm "amdgpu.send_sigterm=1") ++
        (optional cfg.kernelParams.amdgpu.bapm "amdgpu.bapm=1") ++
        (optional cfg.kernelParams.amdgpu.mes "amdgpu.mes=1") ++
        (optional cfg.kernelParams.amdgpu.uniMes "amdgpu.uni_mes=1") ++
        (optional cfg.kernelParams.amdgpu.xgmiP2p "amdgpu.use_xgmi_p2p=1") ++
        (optional cfg.kernelParams.amdgpu.pcieP2p "amdgpu.pcie_p2p=1");

      boot.kernelPackages = mkIf cfg.useLatestKernel pkgs.linuxPackages_latest;
    }
  ]);
}
