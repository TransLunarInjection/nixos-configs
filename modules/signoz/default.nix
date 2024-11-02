{ config, pkgs, lib, ... }:

let
  #   signozSource = pkgs.fetchFromGitHub {
  #   owner = "SigNoz";
  #   repo = "signoz";
  #   rev = "a023a7514e69d461f5e5b37a1f9a0053375e3468";
  #   hash = "sha256-rCzwSTFseOKPe4wPiRMID4X77uxI8NYVZa36gfEOZ+g=";
  # };
  signozSource = pkgs.fetchFromGitHub {
    owner = "SigNoz";
    repo = "signoz";
    rev = "v0.54.0";
    hash = "sha256-qt+XSZirEHHRUs5/eQSYFnPc/UZiZR/APl2g6acvJFo=";
  };
  dataDir = "/var/lib/signoz-test/";
  configDirCH = "${signozSource}/deploy/docker/clickhouse-setup";
  configDirCom = "${signozSource}/deploy/docker/common";
  net = "signoz-net";
  useNet = "--network=${net}";
  enableSignoz = false;
  enableSignozContainers = false;
in
{
  config = lib.mkIf enableSignoz {
    # FIXME: needs to work with firewall on! :c
    networking.firewall.enable = false;
    networking.firewall.checkReversePath = false;
    networking.firewall.trustedInterfaces = [ "docker0" "br*" "br+" "docker+" ];
    networking.firewall.interfaces."docker+".allowedUDPPorts = [ 53 5353 ];
    networking.firewall.interfaces."br-+".allowedUDPPorts = [ 53 5353 ];
    system.activationScripts.mkSignozNet = ''
      ${pkgs.docker}/bin/docker network create ${net} &2>/dev/null || true
    '';
    virtualisation.oci-containers.containers = lib.mkIf enableSignozContainers {
      signoz-zookeeper-1 = {
        image = "bitnami/zookeeper:3.7.1";
        environment = {
          ZOO_SERVER_ID = "1";
          ALLOW_ANONYMOUS_LOGIN = "yes";
          ZOO_AUTOPURGE_INTERVAL = "1";
        };
        ports = [
          "2181:2181"
          "2888:2888"
          "3888:3888"
        ];
        volumes = [
          "${dataDir}/zookeeper-1:/bitnami/zookeeper"
        ];
        extraOptions = [
          "--hostname=zookeeper-1"
          "--user=root"
          useNet
        ];
      };
      signoz-clickhouse = {
        hostname = "clickhouse";
        image = "clickhouse/clickhouse-server:24.1.2-alpine";
        dependsOn = [ "signoz-zookeeper-1" ];
        volumes = [
          "${configDirCH}/clickhouse-config.xml:/etc/clickhouse-server/config.xml:ro"
          "${configDirCH}/clickhouse-users.xml:/etc/clickhouse-server/users.xml:ro"
          "${configDirCH}/clickhouse-cluster.xml:/etc/clickhouse-server/config.d/cluster.xml"
          "${dataDir}/clickhouse/:/var/lib/clickhouse/"
        ];
        extraOptions = [
          useNet
          # FIXMIE: ulimits borked?
          #"--ulimit nproc:65535"
          #"--ulimit nofile:262144:262144"
        ];
      };

      signoz-alertmanager = {
        hostname = "alertmanager";
        image = "signoz/alertmanager:0.23.5";
        volumes = [
          "${dataDir}/alertmanager:/data"
        ];
        cmd = [
          "--queryService.url=http://query-service:8085"
          "--storage.path=/data"
        ];
        extraOptions = [ useNet ];
        dependsOn = [ "signoz-query-service" ];
      };

      signoz-query-service = {
        hostname = "query-service";
        image = "signoz/query-service:0.54.0";
        environment = {
          ClickHouseUrl = "tcp://clickhouse:9000";
          ALERTMANAGER_API_PREFIX = "http://alertmanager:9093/api/";
          SIGNOZ_LOCAL_DB_PATH = "/var/lib/signoz/signoz.db";
          DASHBOARDS_PATH = "/root/config/dashboards";
          STORAGE = "clickhouse";
          GODEBUG = "netdns=go";
          TELEMETRY_ENABLED = "true";
          DEPLOYMENT_TYPE = "docker-swarm";
        };
        volumes = [
          "${configDirCH}/prometheus.yml:/root/config/prometheus.yml:ro"
          "${dataDir}/dashboards:/root/config/dashboards"
          "${dataDir}/signoz/:/var/lib/signoz/"
        ];
        cmd = [
          "-config=/root/config/prometheus.yml"
        ];
        dependsOn = [
          "signoz-clickhouse"
          # "signoz-otel-collector-migrator"
        ];
        extraOptions = [ useNet ];
      };
      signoz-frontend = {
        image = "signoz/frontend:0.54.0";
        ports = [
          "3301:3301"
        ];
        volumes = [
          "${configDirCom}/nginx-config.conf:/etc/nginx/conf.d/default.conf:ro"
        ];
        dependsOn = [
          # "signoz-alertmanager"
          #"signoz-query-service"
        ];
        extraOptions = [
          useNet
          #"--restart on-failure"
        ];
      };

      # TODO: send systemd syslog to otel-collector with systemd-netlogd?
      signoz-otel-collector = {
        hostname = "otel-collector";
        image = "signoz/signoz-otel-collector:0.102.8";

        environment =
          let
            inherit (config.networking) hostName;
            osType = "nixos-${pkgs.system}";
            # serviceName = "otel-collector";
            # taskName = config.services.signoz.taskName;
          in
          {
            OTEL_RESOURCE_ATTRIBUTES = "deployment.environment=production,host.name=${hostName},os.type=${osType}"; #,dockerswarm.service.name=${serviceName},dockerswarm.task.name=${taskName}";
            DOCKER_MULTI_NODE_CLUSTER = "false";
            LOW_CARDINAL_EXCEPTION_GROUPING = "false";
          };
        volumes = [
          #"${configDirCH}/otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro"
          "${./collector.yaml}:/etc/otel-collector-config.yaml:ro"
          "${configDirCH}/otel-collector-opamp-config.yaml:/etc/manager-config.yaml:ro"
          "/var/lib/docker/containers:/var/lib/docker/containers:ro"
          "/:/hostfs:ro"
        ];
        ports = [
          "4317:4317"
          "4318:4318"
        ];
        cmd = [
          "--config=/etc/otel-collector-config.yaml"
          "--manager-config=/etc/manager-config.yaml"
          "--feature-gates=-pkg.translator.prometheus.NormalizeName"
        ];
        extraOptions = [
          "--user=root"
          useNet
        ];
        dependsOn = [
          "signoz-clickhouse"
          #"signoz-otel-collector-migrator"
          "signoz-query-service"
        ];
      };

      # FIXME: this needs to count as a success if it starts then stops with no errors
      # SuccessExitStatus= maybe ?
      signoz-otel-collector-migrator = {
        hostname = "otel-collector-migrator";
        image = "signoz/signoz-schema-migrator:0.102.8";
        cmd = [
          "--dsn=tcp://clickhouse:9000"
        ];
        dependsOn = [ "signoz-clickhouse" ];
        extraOptions = [ useNet ];
      };

      signoz-logspout = {
        hostname = "logspout";
        image = "gliderlabs/logspout:v3.2.14";
        volumes = [
          "/etc/hostname:/etc/host_hostname:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
        cmd = [ "syslog+tcp://otel-collector:2255" ];
        dependsOn = [ "signoz-otel-collector" ];

        extraOptions = [ useNet ];
      };

      # signoz-hotrod = {
      #   image = "jaegertracing/example-hotrod:1.30";
      #   environment.JAEGER_ENDPOINT = "http://otel-collector:14268/api/traces";
      #   cmd = [ "all" ];
      #   extraOptions = [useNet];
      # };

      # signoz-load-hotrod = {
      #   image = "signoz/locust:1.2.3";
      #   environment = {
      #     ATTACKED_HOST = "http://hotrod:8080";
      #     LOCUST_MODE = "standalone";
      #     NO_PROXY = "standalone";
      #     TASK_DELAY_FROM = "5";
      #     TASK_DELAY_TO = "30";
      #     QUIET_MODE = "\${QUIET_MODE:-false}";
      #     LOCUST_OPTS = "--headless -u 10 -r 1";
      #   };
      #   volumes = [
      #     "${configDirCom}/locust-scripts:/locust:ro"
      #   ];
      #   hostname = "load-hotrod";
      #   extraOptions = [
      #     useNet
      #   ];
      # };
    };
  };
}
