{ config, pkgs, lib, flakeArgs, ... }:

# borrowed some stuff from https://github.com/georgewhewell/nixos-host/blob/master/profiles/router.nix
# also begyn.be https://francis.begyn.be/blog/ipv6-nixos-router
# also https://github.com/skogsbrus/os/blob/406df9a6e38a805fdae8e683fe43b5a6c320b2ec/sys/router.nix https://skogsbrus.xyz/blog/2022/06/12/router/
let
  name = "router";
  wanInterface = "enp1s0f1"; # f1/f0 = top two ports
  lanInterface = "enp1s0f2"; # f2/f3 = bottom two ports
  useLanBridge = false;
  lanBridge = if useLanBridge then "br0" else lanInterface;
  debugInterface = "enp2s0f0"; # onboard port (should be eno1 but platform firmware is missing info)
  lanV4Subnet = "10.5.5";
  lanV4Self = "${lanV4Subnet}.1";
  fullHostName = "${config.networking.hostName}.${config.networking.domain}";
  btrfsOpts = [ "rw" "noatime" "compress=zstd" "space_cache=v2" "noatime" "autodefrag" ];
  btrfsSsdOpts = btrfsOpts ++ [ "ssd" "discard=async" ];
  btrfsHddOpts = btrfsOpts;
  netFqdn = "home.moonstruck.dev";
  lanULA = "fd79:fc8d:af3a:ad8b::";
  selfULA = "${lanULA}1";
  nameservers = [
    # quad9
    "9.9.9.9"
    "149.112.112.112"
    "2620:fe::fe"
    "2620:fe::9"
    # cloudflare
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  # cloudVPNInterface = "wg0-cloud";
  # swapsVPNInterface = "wg1-swaps";
  # vpnInterfaces = [ ];
  #lanBridge = "br0.lan";
  swap = "/dev/disk/by-partlabel/${name}_swap";
  resholvCfg = {
    inputs = with pkgs; [
      coreutils
      bash
      findutils
      gnugrep
      curl
      jq
      iproute2
      gawk
      procps
    ];
    interpreter = "${pkgs.bash}/bin/bash";
    execer = [
      # See https://github.com/abathur/resholve/issues/77
      "cannot:${pkgs.borgbackup}/bin/borg"
      "cannot:${pkgs.iproute2}/bin/ip"
      "cannot:${pkgs.iproute2}/bin/tc"
    ];
    fake.external = [ "sudo" ];
  };
  nixos-cake = pkgs.resholve.writeScriptBin "nixos-cake" resholvCfg (builtins.readFile ./nixos-cake.sh);
  # nixos-cake = pkgs.runCommand "nixos-cake" { } ''
  #   mkdir -p $out/bin
  #   cp ${./nixos-cake.sh} $out/bin/nixos-cake
  #   chmod +x $out/bin/nixos-cake
  # '';
in
{
  imports = [
    ./samba.nix
    # WIP:
    # ./lgtm.nix
  ];

  config = {
    sconfig.machineId = "62df49c6dd7668e60028ed7c7f8b009d";
    system.stateVersion = "22.11";

    boot.kernelParams = [ ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
    boot.initrd.kernelModules = [ ];

    # lib.mkForce is important here, want to make sure service modules
    # don't open ports to the outside world
    networking = lib.mkForce {
      inherit nameservers;
      hostName = "${name}-nixos";
      domain = netFqdn;
      useDHCP = false;
      nat = {
        enable = true;
        externalInterface = wanInterface;
        internalInterfaces = [ lanBridge ];
      };
      useNetworkd = true;
      networkmanager.enable = false;
      extraHosts = ''
        ${lanV4Self} ${fullHostName}
      '';
      firewall = {
        enable = true;
        logReversePathDrops = true;
        logRefusedConnections = true;
        logRefusedPackets = true;
        logRefusedUnicastsOnly = false;
        rejectPackets = true;
        trustedInterfaces = [ lanBridge debugInterface "lo" ];
        allowedUDPPorts = [ ];
        allowedTCPPorts = [ ];
        allowedUDPPortRanges = [ ];
        allowedTCPPortRanges = [ ];
      };
      # not sure whether to use a bridge
      # bridges."${lanBridge}" = {
      #   interfaces = [
      #     lanInterface
      #   ];
      # };  
    };
    lun.profiles = {
      server = true;
      personal = false;
      gaming = false;
      graphical = false;
    };
    security.sudo.wheelNeedsPassword = false;
    services.resolved.enable = false;
    systemd.network = {
      wait-online.anyInterface = true;
      links."99-default.link.d/offload.conf" = {
        linkConfig = {
          ReceiveChecksumOffload = false;
          TransmitChecksumOffload = false;
          TCPSegmentationOffload = false;
          TCP6SegmentationOffload = false;
          GenericSegmentationOffload = false;
          GenericReceiveOffload = false;
          LargeReceiveOffload = false;
        };
      };
      networks = {
        "wan" = {
          name = wanInterface;
          networkConfig = {
            DHCP = "yes";
            Description = "ISP interface";
            IPv6AcceptRA = true;
          };
          linkConfig = {
            RequiredForOnline = "routable";
          };
          dhcpV6Config = {
            PrefixDelegationHint = "::/48";
          };
          ipv6PrefixDelegationConfig = {
            Managed = true;
          };
        };
        "dbg" = {
          name = debugInterface;
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            ConfigureWithoutCarrier = "yes";
          };
        };
        "lanBridge" = {
          name = lanBridge;
          addresses = [
            { Address = "${selfULA}/64"; }
            { Address = "${lanV4Self}/24"; }
          ];
          networkConfig = {
            DHCP = "no";
            Description = "LAN interface";
            # the client shouldn't be allowed to send us RAs, that would be weird.
            IPv6AcceptRA = false;
            IPv6SendRA = true;
            ConfigureWithoutCarrier = "yes";

            # Just delegate prefixes from the DHCPv6 PD pool.
            # If you also want to distribute a local ULA prefix you want to
            # set this to `yes` as that includes both static prefixes as well
            # as PD prefixes.
            DHCPPrefixDelegation = "yes";
          };
          # finally "act as router" (according to systemd.network(5))
          ipv6PrefixDelegationConfig = {
            RouterLifetimeSec = 300; # required as otherwise no RA's are being emitted

            # In a production environment you should consider setting these as well:
            EmitDNS = true;
            EmitDomains = true;
            DNS = "fe80::1"; # or whatever "well known" IP your router will have on the inside.
          };

          # Add ULA prefix
          ipv6Prefixes = [
            {
              Prefix = "${lanULA}/64";
              AddressAutoconfiguration = true;
              PreferredLifetimeSec = 1800;
              ValidLifetimeSec = 1800;
            }
          ];
        };
      } // (lib.optionalAttrs useLanBridge {
        "lan" = {
          name = lanInterface;
          networkConfig = {
            DHCP = "no";
            Bridge = lanBridge;
          };
        };
      });
    } // (lib.optionalAttrs useLanBridge {
      netdevs = {
        bridge = {
          netdevConfig = {
            Name = lanBridge;
            Kind = "bridge";
          };
          extraConfig = ''
            [Bridge]
            DefaultPVID=none
            VLANFiltering=yes
          '';
        };
      };
    });
    systemd.targets.network-online.wants = [ "systemd-networkd-wait-online.service" ];
    systemd.services.dnsmasq.wants = [ "network-online.target" ];
    systemd.services.avahi.wants = [ "network-online.target" ];
    systemd.services.miniupnpd.wants = [ "network-online.target" ];
    systemd.services.lldpd.wants = [ "network-online.target" ];
    # TODO: consider
    # unbound?
    # https://old.reddit.com/r/NixOS/comments/innzkw/pihole_style_adblock_with_nix_and_unbound/g48o0qb/
    # dnsmasq handles dhcp and dns
    services.dnsmasq = {
      enable = true;
      settings = {
        domain-needed = true;
        bogus-priv = true;
        no-resolv = true;
        stop-dns-rebind = true;
        server = nameservers;
        cache-size = 10000;
        expand-hosts = true;
        domain = netFqdn;
        local = "/${netFqdn}/";
        # FIXME: need to listen on V6
        listen-address = "::1,127.0.0.1,${lanV4Self},${selfULA}";
        # Explicitly set router's address and turn off /etc/hosts
        # Fixes strange issue where router.fqdn resolved AAAA ::1
        address = [
          "/router.${netFqdn}/${lanV4Self}"
          "/router.${netFqdn}/${selfULA}"
          "/${config.networking.hostName}.${netFqdn}/${lanV4Self}"
          "/${config.networking.hostName}.${netFqdn}/${selfULA}"
        ];
        no-hosts = true;
        dhcp-authoritative = true;
        dhcp-range = "${lanV4Subnet}.50,${lanV4Subnet}.254,24h";
        dhcp-option = [
          "option:router,${lanV4Self}"
          "option:mtu,1500"
        ];
        # static IPs:
        # dhcp-host = [
        #   "MAC,ipaddr"
        # ];
      };
    };
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
      # "net.ipv4.tcp_ecn" = 1; # Tested it on, works badly

      # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
      # By default, not automatically configure any IPv6 addresses.
      "net.ipv6.conf.all.accept_ra" = 0;
      "net.ipv6.conf.all.autoconf" = 0;
      "net.ipv6.conf.all.use_tempaddr" = 0;

      # On WAN, allow IPv6 autoconfiguration and tempory address use.
      "net.ipv6.conf.${wanInterface}.accept_ra" = 2;
      "net.ipv6.conf.${wanInterface}.autoconf" = 1;
      "net.ipv6.conf.${debugInterface}.accept_ra" = 2;
      "net.ipv6.conf.${debugInterface}.autoconf" = 1;
    };
    # services.corerad = {
    #   enable = true;
    #   settings = {
    #     debug = {
    #       address = "localhost:9430";
    #       prometheus = true; # enable prometheus metrics
    #     };
    #     interfaces = [
    #       {
    #         name = lanInterface;
    #         advertise = true;
    #         prefix = [
    #           { prefix = "::/64"; }
    #           { prefix = "${lanULA}::/64"; }
    #         ];
    #       }
    #     ];
    #   };
    # };
    services.miniupnpd = {
      enable = true;
      externalInterface = wanInterface;
      internalIPs = [ lanBridge ];
      natpmp = true;
      upnp = true;
    };
    services.avahi = lib.mkForce {
      enable = true;
      allowInterfaces = [ lanBridge ];
      ipv4 = true;
      ipv6 = true;
      reflector = true;
    };

    lun.persistence.dirs = [
      "/var/lib/dnsmasq"
      "/var/tmp"
      "/tmp"
      "/persist/thoth/ftmp"
      "/nix" # single sub-vol persistence setup
    ];

    services.lldpd.enable = true;
    lun.home-assistant.enable = true;
    services.plex = {
      enable = true;
      openFirewall = true;
      dataDir = "/persist/plex/";
    };

    systemd.services.nightly-reboot = {
      description = "Machine reboot";

      serviceConfig = {
        type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl --force reboot";
      };

      startAt = "*-*-* 06:00:00";
    };
    systemd.services.apply-nixos-cake = {
      description = "Apply nixos-cake";

      serviceConfig = {
        type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${lib.getExe nixos-cake}";
      };

      startAt = "*-*-* *:05:00";
    };

    # spin down hdds and apply cake
    powerManagement.powerUpCommands = with pkgs;''
      ${bash}/bin/bash -c "${hdparm}/bin/hdparm -S 9 -B 127 $(${utillinux}/bin/lsblk -dnp -o name,rota |${gnugrep}/bin/grep \'.*\\s1\'|${coreutils}/bin/cut -d \' \' -f 1)"
      ${bash}/bin/bash -c "bash ${lib.getExe nixos-cake} || true"
    '';

    boot.kernelModules = [ "tcp_bbr" "sch_cake" ];
    boot.kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = lib.mkForce "cubic"; # Not using BBR for router because want cake
      "net.core.default_qdisc" = lib.mkForce "cake"; # FIXME doesn't apply to all nics, set too late in boot?
      "net.netfilter.nf_conntrack_buckets" = 65536;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = 7200; # 2 hours
      # "net.netfilter.nf_conntrack_max" = 1048576;
      "net.netfilter.nf_conntrack_generic_timeout" = 300;
      "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 90;
      "net.netfilter.nf_conntrack_tcp_timeout_fin_wait" = 90;
      "net.netfilter.nf_conntrack_tcp_timeout_unacknowledged" = 90;
      "net.netfilter.nf_conntrack_tcp_timeout_syn_sent" = 90;
      "net.netfilter.nf_conntrack_icmp_timeout" = 45;
      "net.netfilter.nf_conntrack_icmpv6_timeout" = 45;
    };

    hardware.cpu.amd.updateMicrocode = true;

    users.mutableUsers = false;

    systemd.targets.getty.wants = [ "journal@tty12.service" ];

    systemd.services."thoth-lun" =
      let
        thothPython = pkgs.python3.withPackages (_: [
          flakeArgs.thoth-reminder-bot.packages.${pkgs.system}.thoth
        ]);
        thothWorkingDirectory = "/persist/thoth/ftmp/";
        thothEnv = "${thothWorkingDirectory}secrets.env";
      in
      {
        enable = true;
        description = "Thoth reminder bot instance managed by @lun";
        wantedBy = [ "multi-user.target" ];
        wants = [
          "network-online.target"
          "dnsmasq.service"
        ];
        unitConfig = {
          ConditionPathExists = thothEnv;
          StartLimitBurst = 5;
          StartLimitIntervalSec = 30;
        };
        serviceConfig = {
          EnvironmentFile = thothEnv;
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c "cd ${thothWorkingDirectory}; sleep 2; ${thothPython}/bin/python -c 'import thoth.main; thoth.main.start()'"
          '';
          Type = "exec";
          RestartSec = 30;
          TemporaryFileSystem = "/persist/";
          BindPaths = thothWorkingDirectory;
          PrivateTmp = true;
          Restart = "always";
          ProtectSystem = true;
          ProtectHome = true;
        };
      };

    environment.systemPackages = [
      nixos-cake
      # pkgs.netsniff-ng # build fails
      pkgs.ethtool
      pkgs.iftop
    ];

    lun.persistence.enable = true;
    fileSystems = {
      "/" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "defaults" "size=2G" "mode=755" ];
      };
      "/boot" = {
        device = "/dev/disk/by-partlabel/${name}_esp";
        fsType = "vfat";
        neededForBoot = true;
        options = [ "discard" "noatime" ];
      };
      "/persist" = {
        device = "/dev/disk/by-partlabel/${name}_persist";
        fsType = "btrfs";
        neededForBoot = true;
        options = btrfsSsdOpts ++ [ "subvol=@persist" "nodev" "nosuid" ];
      };
      "/nix" = {
        neededForBoot = true;
      };
      "/mnt/_nas0" = {
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/_nas0";
        neededForBoot = false;
        options = btrfsHddOpts ++ [ "nofail" ];
      };
    };
    swapDevices = lib.mkForce [
      { device = swap; }
    ];
    boot.resumeDevice = swap;
  };
}
