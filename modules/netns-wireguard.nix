# From:
# https://github.com/delroth/infra.delroth.net/blob/a324795639497fb6df998278928ddb2c8d113f5b/services/wg-netns.nix
# TODO: same but with wg-quick and pre/post
# another ref https://github.com/Steav005/home-config/blob/8d3623edb37b335fac6ad99198cc71d5f4efa6fa/nixos/torrent.nix

# A NixOS service that runs Wireguard in a netns, and can be bound to by other
# services to isolate their networking.
#
# Currently only supports one Wireguard namespace, but nothing should prevent
# running multiple, it just needs some NixOS config refactoring work.
#
# WARNING: currently this leaks DNS! Services inside the netns can talk to nscd
# outside and perform DNS resolutions this way. For my current set of use cases
# this is not a problem.

{ config, lib, pkgs, ... }:

let
  cfg = config.lun.wg-netns;
  ip = "${pkgs.iproute2}/bin/ip";
  ifName = "wg0";
  nsName = "wg";

  resolvconf = pkgs.writeText "wg-resolv.conf" "nameserver 8.8.8.8";
  nsswitchconf = pkgs.writeText "wg-nsswitch.conf" "hosts: files dns";
in
{
  options.lun.wg-netns = with lib; {
    enable = mkEnableOption "Wireguard netns container";

    privateKey = mkOption {
      type = types.str;
      description = ''
        Wireguard private key for this host.
      '';
    };

    peerPublicKey = mkOption {
      type = types.str;
      description = ''
        Wireguard public key of the peer host.
      '';
    };

    endpointAddr = mkOption {
      type = types.str;
      description = ''
        IP:port of the Wireguard endpoint to connect to.
      '';
    };

    ip4 = mkOption {
      type = types.str;
      description = ''
        Local IPv4 of this host on the Wireguard interface.
      '';
    };

    ip6 = mkOption {
      type = types.str;
      description = ''
        Local IPv6 of this host on the Wireguard interface.
      '';
    };

    isolateServices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Names of systemd services to "patch" to force them to run inside the
        Wireguard network namespace.
      '';
    };

    forwardPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = ''
        Port numbers that services listen on in the Wireguard netns and that
        should be exposed (listening on ::1 only) in the outer netns.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "wireguard" ];
    environment.systemPackages = [ pkgs.wireguard-tools ];

    systemd =
      let
        patchedServices = lib.genAttrs cfg.isolateServices (_svcname: {
          bindsTo = [ "wireguard.service" "netns@${nsName}.service" ];
          after = [ "wireguard.service" ];
          # requires = [ "wireguard-netns-init.service" ];
          unitConfig.JoinsNamespaceOf = "netns@${nsName}.service";
          serviceConfig = {
            PrivateNetwork = true;
            # NetworkNamespacePath = nsPath;
            BindReadOnlyPaths = [
              "${resolvconf}:/etc/resolv.conf"
              "${nsswitchconf}:/etc/nsswitch.conf"
            ];
          };
        });

        forwardSockets = builtins.listToAttrs (map
          (port: {
            name = "wireguard-netns-forward-${toString port}";
            value = {
              wantedBy = [ "sockets.target" ];
              socketConfig.ListenStream = port;
            };
          })
          cfg.forwardPorts);

        forwardServices = builtins.listToAttrs (map
          (port: rec {
            name = "wireguard-netns-forward-${toString port}";
            value = {
              requires = [ "${name}.socket" ];
              after = [ "${name}.socket" ];
              unitConfig.JoinsNamespaceOf = "netns@${nsName}.service";
              serviceConfig = {
                #NetworkNamespacePath = nsPath;
                PrivateNetwork = true;
                ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString port}";
              };
            };
          })
          cfg.forwardPorts);
      in
      {
        services = patchedServices // forwardServices // {
          "netns@" = {
            description = "%I network namespace";
            before = [ "network.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              PrivateNetwork = true;
              PrivateMounts = false;
              ExecStart = (pkgs.writeShellScript "netns-up" ''
                set -xe
                ${pkgs.iproute2}/bin/ip netns add $1
                ${pkgs.utillinux}/bin/umount /var/run/netns/$1
                ${pkgs.utillinux}/bin/mount --bind /proc/self/ns/net /var/run/netns/$1
              '') + " %I";
              ExecStop = "${pkgs.iproute2}/bin/ip netns del %I";
            };
          };

          wireguard = {
            description = "wireguard VPN client";
            bindsTo = [ "netns@${nsName}.service" ];
            requires = [ "network-online.target" "netns@${nsName}.service" ];
            after = [ "wireguard-netns-init.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writers.writeDash "wireguard-up" ''
                ${ip} -n ${nsName} route del default dev ${ifName} || true
                ${ip} -n ${nsName} -6 route del default dev ${ifName} || true
                ${ip} route del default dev ${ifName} || true
                ${ip} -n ${nsName} link del ${ifName} || true
                ${ip} link del ${ifName} || true
                # Note: creating the iface in the outer netns means that wg will
                # "remember" the packets need to go through the outer netns.
                set -xe
                ${ip} link add ${ifName} type wireguard
                ${pkgs.wireguard-tools}/bin/wg set ${ifName} \
                    private-key '${cfg.privateKey}' \
                    peer '${cfg.peerPublicKey}' \
                    endpoint '${cfg.endpointAddr}' \
                    allowed-ips '0.0.0.0/0,::0/0'
                ${ip} link set ${ifName} netns ${nsName}
                ${ip} -n ${nsName} link set ${ifName} up
                ${ip} -n ${nsName} addr add ${cfg.ip4} dev ${ifName}
                ${ip} -n ${nsName} -6 addr add ${cfg.ip6} dev ${ifName}
                ${ip} -n ${nsName} route add default dev ${ifName}
                ${ip} -n ${nsName} -6 route add default dev ${ifName}
              '';
              ExecStop = pkgs.writers.writeDash "wireguard-down" ''
                set -xe
                ${ip} -n ${nsName} route del default dev ${ifName} || true
                ${ip} -n ${nsName} -6 route del default dev ${ifName} || true
                ${ip} -n ${nsName} link del ${ifName}
              '';
            };
          };
        };

        sockets = forwardSockets;
      };
  };
}
