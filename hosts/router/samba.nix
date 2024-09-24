{ config, lib, ... }:
{
  config = {
    lun.persistence.dirs = [ "/var/lib/samba" ];
    services.samba-wsdd.enable = true;
    services.samba-wsdd.interface = "enp1s0f2";
    services.samba = {
      enable = true;
      openFirewall = lib.mkForce false;
      securityType = "user";

      settings.global = {
        workgroup = "WORKGROUP";
        "server string" = "router";
        "server role" = "standalone server";
        "map to guest" = "bad user";
        "bind interfaces only" = "yes";
        "interfaces" = "lo enp1s0f2";
      };

      shares = {
        media = {
          path = "/mnt/_nas0/main/Plex/";
          comment = "Plex Media";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0771";
          "directory mask" = "0775";
          # NOTE: need to `sudo smbpasswd -a username` to be able to log in
          "force user" = "lun";
          "force group" = "users";
        };
      };
    };
  };
}
