{ lib, config, ... }:
let cfg = config.lun.home-assistant; in
{
  options = {
    lun.home-assistant.enable = lib.mkEnableOption "enable HA containers";
  };
  config = lib.mkIf cfg.enable {
    lun.persistence.dirs = [ "/var/lib/home-assistant" ];

    systemd.services.podman.after = [ "NetworkManager-wait-online.service" ];
    systemd.services.podman.wants = [ "NetworkManager-wait-online.service" ];
    systemd.services.docker.after = [ "NetworkManager-wait-online.service" ];
    systemd.services.docker.wants = [ "NetworkManager-wait-online.service" ];

    virtualisation.oci-containers = {
      containers.homeassistant = {
        volumes = [ "/var/lib/home-assistant/main:/config" ];
        environment.TZ = "America/Los_Angeles";
        # https://github.com/home-assistant/core/pkgs/container/home-assistant/versions?filters%5Bversion_type%5D=tagged
        image = "ghcr.io/home-assistant/home-assistant:2024.9 ";
        extraOptions = [
          "--network=host"
          "--device=/dev/ttyUSB0:/dev/ttyUSB0"
        ];
        # this is a bodge to ensure pyemvue is in the container
        # but I don't want to have to host my own ha container builds somewhere
        # and it's good enough for now
        entrypoint = "/bin/bash";
        cmd = [
          "-c"
          "set -e; sleep 1; /usr/local/bin/pip3 install --upgrade pip setuptools wheel; /usr/local/bin/pip3 install 'pyemvue==0.18.*'; exec /init"
        ];
      };
      containers.homeassistant-zwave = {
        volumes = [ "/var/lib/home-assistant/zwave:/usr/src/app/store" ];
        environment.TZ = "America/Los_Angeles";
        # https://hub.docker.com/r/zwavejs/zwave-js-ui/tags
        image = "zwavejs/zwave-js-ui:9";
        extraOptions = [
          "--network=host"
          "--device=/dev/serial/by-id/usb-Silicon_Labs_Zooz_ZST10_700_Z-Wave_Stick_0001-if00-port0:/dev/zwave"
        ];
      };
    };
  };
}
