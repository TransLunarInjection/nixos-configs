{ config, lib, ... }:
let
  cfg = config.lun.amd-mem-encrypt;
in
{
  options.lun.amd-mem-encrypt = {
    enable = lib.mkEnableOption ''
      Enable AMD memory encryption.
      This protects the host system and containers. Further config may be needed for VMs. ("nested paging")
      See https://libvirt.org/kbase/launch_security_sev.html
    '';
    patchEnable = lib.mkEnableOption "Enable AMD_MEM_ENCRYPT kconfig option. Usually not needed, is already Y or M.";
  };
  config = lib.mkIf cfg.enable {
    system.requiredKernelConfig = with config.lib.kernelConfig; [
      (isEnabled "AMD_MEM_ENCRYPT")
      (isEnabled "X86_MEM_ENCRYPT")
      (isEnabled "KVM_AMD_SEV")
      # Unsure if this is needed on host - probably guest only
      # (isEnabled "SEV_GUEST")
    ];
    boot = {
      kernelParams = [
        "kvm_amd.sev=1"
        "mem_encrypt=on"
      ];
      kernelPatches = lib.mkIf cfg.patchEnable [
        {
          name = "enable-amd-sme-sev";
          patch = null;
          extraStructuredConfig = with lib.kernel; {
            AMD_MEM_ENCRYPT = yes;
          };
        }
      ];
    };
  };
}
