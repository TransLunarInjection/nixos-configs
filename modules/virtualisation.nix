{ pkgs, config, lib, ... }:
{
  options.lun.virtualisation.enable = lib.mkEnableOption "virt" // { default = true; };
  config = lib.mkMerge [
    {
      # Not using NixOS containers currently
      boot.enableContainers = false;
    }
    (lib.mkIf config.lun.virtualisation.enable {

      virtualisation = {
        # FIXME: rootless podman keeps fucking up so disabling it for now
        # podman = {
        #   enable = true;
        #   dockerCompat = true; # docker alias
        # };
        docker.enable = true;
        oci-containers.backend = "docker";
      };

      lun.persistence.dirs = [
        "/var/lib/docker"
        "/var/lib/containers"
        "/var/lib/libvirt"
      ];

      environment.systemPackages = with pkgs; [
        virt-manager
        virtiofsd
      ];

      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          ovmf.enable = true;
          runAsRoot = false;
        };
        onBoot = "ignore";
        onShutdown = "shutdown";
      };
    })
  ];
}
