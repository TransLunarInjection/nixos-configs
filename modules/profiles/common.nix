{ config, pkgs, lib, ... }:
{
  options.lun.profiles.common = (lib.mkEnableOption "Enable common profile") // { default = true; };

  config = lib.mkIf config.lun.profiles.common {
    my.home-manager.enabled-users = [ "lun" ];

    # LANGUAGE / I18N
    i18n = let locale = "en_US.UTF-8"; in
      {
        defaultLocale = locale;
        supportedLocales = [ "${locale}/UTF-8" ];
      };
    time = {
      timeZone = "America/Los_Angeles";
    };
    services.xserver.xkb.layout = "us";
    services.xserver.xkb.variant = "altgr-intl"; # «cool and new»
    services.xserver.xkb.options = "compose:rwin"; # grp:caps_toggle,grp_led:scroll
    # CONSOLE
    console = {
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u12n.psf.gz";
      keyMap = "us";
    };
    # Persist console when getty starts
    # systemd.services."getty@".serviceConfig.TTYVTDisallocate = "no";

    # LOGGING
    # FIXME: I want 
    # MaxLevelStore=5
    # for old logs but not for logs from current session,
    # is that possible?
    # Otherwise if a service fails to start sometimes there are no useful logs
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      MaxFileSec=1day
      MaxRetentionSec=1week
    '';

    # NIX
    nix = {
      # Trying out Lix, was previously pinned to nix 2.16 due to bugs in newer versions
      # package = pkgs.nixVersions.nix_2_16; # FIXME: revert after https://github.com/NixOS/nix/issues/9052
      daemonCPUSchedPolicy = "idle";
      extraOptions = lib.mkMerge [
        "experimental-features = nix-command flakes"
        "warn-dirty = false"
      ];
      settings = {
        auto-optimise-store = true;
        trusted-users = [ "@wheel" ];
        max-substitution-jobs = 24;
      };
    };

    # NETWORKING
    networking = {
      networkmanager.enable = true;
      # TODO: file bug for iwd network connection secrets issue
      # networkmanager.wifi.backend = "iwd";
    };
    services.avahi = {
      enable = true;
      nssmdns6 = true; # TODO: does this cause too much delay like the nssmdns4 option suggests?
      nssmdns4 = true;
      publish.enable = true;
      publish.addresses = true;
    };

    # SSH
    services.openssh = {
      enable = true;
      banner = "This computer system may not be used for any purpose. Be gay, do crime.\n";
      startWhenNeeded = true;
      # RSA might be broken, make sure we use ed25519 keys
      # https://www.schneier.com/blog/archives/2023/01/breaking-rsa-with-a-quantum-computer.html
      hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];
      settings = {
        PermitRootLogin = "no";
        # TODO: ssh-keygen -A at boot so these get generated while still using startWhenNeeded?
        # Maybe should always pregen when setting up a new system because will be using agenix later so this is irrelevant
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    lun.persistence.dirs = [ "/etc/ssh" ];

    # BOOT
    boot = {
      initrd.availableKernelModules = lib.mkIf (pkgs.system == "x86_64-linux") [ "nvme" "ahci" "xhci_pci" "usb_storage" "usbhid" "sd_mod" ];
      initrd.kernelModules = [ "tcp_bbr" ];
      kernelParams = [
        "sysrq_always_enabled"
        "fsck.mode=force"
      ];
      kernelModules = lib.mkIf (pkgs.system == "x86_64-linux") [ "kvm-amd" "kvm-intel" ];
      extraModulePackages = [ ];
      tmp.cleanOnBoot = true;
    };

    # HARDWARE
    hardware = {
      enableRedistributableFirmware = true;
    };
    services.fstrim.enable = true;

    # HARDENING
    nix.settings.allowed-users = [ "@users" ];
    security = {
      sudo.execWheelOnly = true;
      doas.enable = true;
    };
    boot.kernel.sysctl = with lib; {
      "net.core.default_qdisc" = "fq"; # fq best if using bbr https://groups.google.com/g/bbr-dev/c/4jL4ropdOV8
      "net.ipv4.tcp_ecn" = 0; # ECN has been misbehaving locally, don't know why
      "net.ipv4.tcp_congestion_control" = "bbr";

      # https://blog.cloudflare.com/optimizing-tcp-for-high-throughput-and-low-latency/
      "net.core.wmem_max" = 536870912;
      "net.core.rmem_max" = 536870912;
      "net.ipv4.tcp_rmem" = "8192 262144 536870912";
      "net.ipv4.tcp_wmem" = "4096 16384 536870912";
      "net.ipv4.tcp_adv_win_scale" = "-2";
      "net.ipv4.tcp_collapse_max_bytes" = "6291456"; # FIXME: needs patch https://github.com/cloudflare/linux/blob/master/patches/0014-add-a-sysctl-to-enable-disable-tcp_collapse-logic.patch
      "net.ipv4.tcp_notsent_lowat" = "131072";

      # Ignore broadcast ICMP (mitigate SMURF)
      "net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault true;

      #allow all sysrqs
      "kernel.sysrq" = 1;

      # https://github.com/NixOS/nixpkgs/blob/d6fe32c6b9059a054ca0cda9a2bb99753d1134df/nixos/modules/profiles/hardened.nix#L95
      # Enable strict reverse path filtering (that is, do not attempt to route
      # packets that "obviously" do not belong to the iface's network; dropped
      # packets are logged as martians).
      "net.ipv4.conf.all.log_martians" = mkDefault true;
      "net.ipv4.conf.all.rp_filter" = mkDefault "1";
      "net.ipv4.conf.default.log_martians" = mkDefault true;
      "net.ipv4.conf.default.rp_filter" = mkDefault "1";

      # Ignore incoming ICMP redirects (note: default is needed to ensure that the
      # setting is applied to interfaces added after the sysctls are set)
      "net.ipv4.conf.all.accept_redirects" = mkDefault false;
      "net.ipv4.conf.all.secure_redirects" = mkDefault false;
      "net.ipv4.conf.default.accept_redirects" = mkDefault false;
      "net.ipv4.conf.default.secure_redirects" = mkDefault false;
      "net.ipv6.conf.all.accept_redirects" = mkDefault false;
      "net.ipv6.conf.default.accept_redirects" = mkDefault false;

      # Ignore outgoing ICMP redirects (this is ipv4 only)
      "net.ipv4.conf.all.send_redirects" = mkDefault false;
      "net.ipv4.conf.default.send_redirects" = mkDefault false;
    };

    documentation.enable = false;
    documentation.man.enable = false;
    documentation.nixos.enable = false;

    # https://github.com/NixOS/nixpkgs/issues/133063
    systemd.services.NetworkManager-wait-online = {
      serviceConfig.ExecStart = [ "" "${pkgs.networkmanager}/bin/nm-online -q -t 5" ];
    };

    # SYSTEM PACKAGES
    environment.systemPackages = with pkgs; [
      bash
      wget
      curl
      nano
      ripgrep
      fd
      killall
      traceroute
      dnsutils
      libfaketime
      lun.lun
    ];

    # systemd
    systemd.extraConfig = ''
      DefaultTimeoutStopSec=45s
    '';
    systemd.user.extraConfig = ''
      DefaultTimeoutStopSec=45s
    '';

    # CHECKS
    assertions = [
      {
        assertion = config.hardware.cpu.amd.updateMicrocode || config.hardware.cpu.intel.updateMicrocode || pkgs.system != "x86_64-linux";
        message = "updateMicrocode should be set for intel or amd";
      }
    ];
  };
}
