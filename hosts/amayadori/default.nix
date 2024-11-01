{ lib, flakeArgs, ... }:

let
  # https://github.com/cole-mickens/nixcfg/blob/main/mixins/nvidia.nix
  waylandEnv = {
    WLR_RENDERER = "vulkan";
    # VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
    # KWIN_OPENGL_INTERFACE = "egl";
    #    KWIN_EXPLICIT_SYNC = "0";
    #    KWIN_DRM_USE_MODIFIERS = "1";
    #    KWIN_DRM_FORCE_EGL_STREAMS = "0";
    # https://lamarque-lvs.blogspot.com/2021/12/nvidia-optimus-with-wayland-help-needed.html
    #WLR_NO_HARDWARE_CURSORS = "1";
    #KWIN_DRM_DEVICES = drmDevices;
    #WLR_DRM_DEVICES = drmDevices;
    #GBM_BACKEND = "nvidia-drm";
    #GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm";
    #__GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # https://github.com/NVIDIA/libglvnd/blob/master/src/EGL/icd_enumeration.md
    # https://github.com/NixOS/nixpkgs/blob/a0dbe47318bbab7559ffbfa7c4872a517833409f/pkgs/development/libraries/libglvnd/default.nix#L33
    #__EGL_VENDOR_LIBRARY_CONFIG_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d/";
    #__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS = "/etc/egl/egl_external_platform.d/:/run/opengl-driver/share/egl/egl_external_platform.d/";
  };
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./x13s.nix
    ];

  lun.power-saving.enable = true;
  lun.power-saving.usb = true;
  lun.persistence.enable = true;
  lun.persistence.dirs = [
    "/nix"
    "/tmp"
    "/var/lib/sddm"
  ];
  lun.conservative-governor.enable = true;
  #  services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
  services.displayManager.defaultSession = "none+i3";
  lun.virtualisation.enable = lib.mkForce false;


  boot.plymouth.enable = lib.mkForce false;

  networking.hostName = "lun-amayadori-nixos";
  sconfig.machineId = "1f3c8ec5230e763537ec8ef5836f334a";
  system.stateVersion = "23.05";

  systemd.sleep.extraConfig = ''
    AllowHibernation=no
    AllowSuspend=yes
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';

  environment.variables = waylandEnv;
  environment.sessionVariables = waylandEnv;

  boot.kernelParams = [
    #    "mem_sleep_default=deep" # S3 by default
    "nmi_watchdog=0"
    #    "nowatchdog"
  ];

  services.power-profiles-daemon.enable = false;
  powerManagement.powertop.enable = true;
  services.tlp.enable = true;
  services.tlp.settings = {
    PCIE_ASPM_ON_BAT = "powersupersave";
    RUNTIME_PM_ON_AC = "auto";
    # Operation mode when no power supply can be detected: AC, BAT.
    TLP_DEFAULT_MODE = "BAT";
    # Operation mode select: 0=depend on power source, 1=always use TLP_DEFAULT_MODE
    TLP_PERSISTENT_DEFAULT = "1";
    DEVICES_TO_DISABLE_ON_LAN_CONNECT = "wifi wwan";
    DEVICES_TO_DISABLE_ON_WIFI_CONNECT = "wwan";
    DEVICES_TO_DISABLE_ON_WWAN_CONNECT = "wifi";
  };
  # not much RAM available to build with so limit jobs and cores
  nix.settings.max-jobs = 2;
  nix.settings.cores = 4;

  specialisation.cosmic.configuration = {
    imports = [
      flakeArgs.nixos-cosmic.nixosModules.default
    ];

    services.displayManager.cosmic-greeter.enable = true;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.desktopManager.cosmic.enable = true;
    security.pam.services.cosmic-greeter = { };
  };
}

