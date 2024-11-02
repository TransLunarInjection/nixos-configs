{ config, pkgs, lib, ... }:
let telv4 = "100.117.31.62"; in
{
  config = lib.mkMerge [
    {
      networking.firewall.allowedTCPPorts = [ 9001 9002 ];

      services.grafana.provision.datasources.settings = {
        apiVersion = 1;
        datasources = [{
          name = "Prometheus";
          type = "prometheus";
          url = "http://${telv4}:9001";
          orgId = 1;
        }];
        deleteDatasources = [{
          name = "Prometheus";
          orgId = 1;
        }];
      };
      lun.persistence.dirs = [ "/var/lib/grafana" ];
      ## FIXME: https://github.com/tigorlazuardi/nixos/blob/f7dbe0e3fc9da809518e016cd951a5325e22ca82/system/services/telemetry/default.nix#L5
      ## This looks like LGTM stack
      services.opentelemetry-collector = {
        enable = true;
        package = pkgs.opentelemetry-collector-contrib;
        settings = {
          receivers = {
            otlp.protocols.http.endpoint = "${telv4}:3333";
            otlp.protocols.grpc.endpoint = "${telv4}:3334";
          };
          processors.batch = { };
          # processors.spanmetrics.metrics_exporter = "prometheus";
          # exporters.prometheusremotewrite = {
          #   endpoint = "http://${telv4}:9001/api/v1/write";
          #   target_info.enabled = true;
          # };
          exporters.prometheus = {
            endpoint = "${telv4}:9003";
            # target_info.enabled = true;
          };
          exporters.otlphttp = {
            endpoint = "http://${telv4}:3334/otlp/v1/logs"; # loki
          };
          connectors.spanmetrics.namespace = "span.metrics";
          service.pipelines.metrics = {
            receivers = [ "otlp" "spanmetrics" ];
            processors = [ "batch" ];
            exporters = [ "prometheus" ];
          };
          service.pipelines.traces = {
            receivers = [ "otlp" ];
            exporters = [ "spanmetrics" "otlphttp" ];
            # exporters = ["prometheus"];
          };
          service.telemetry.metrics.address = "${telv4}:8899";
        };
      };
      # services.opentelemetry-collector = {
      #   enable = true;
      #   settings = {
      #     receivers = {
      #       otlp = {
      #         protocols = {
      #           http = {
      #             endpoint = "${telv4}:3333";
      #           };
      #         };
      #       };
      #     # hostmetrics = {
      #     #   collection_interval = "10s";
      #     #   scrapers = {
      #     #     cpu = {};
      #     #     disk = {};
      #     #     load = {};
      #     #     filesystem = {};
      #     #     memory = {};
      #     #     network = {};
      #     #     paging = {};
      #     #     processes = {};
      #     #   };
      #     # };
      #     };
      #     exporters = {
      #       # prometheusremotewrite = {
      #       #   endpoint = "http://${telv4}:9001";
      #       # };
      #       prometheus = {
      #         endpoint = "http://${telv4}:9003";
      #       };
      #     };
      #   };
      # };
      # https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20
      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = telv4;
            http_port = 8888;
          };
        };
        dataDir = "/var/lib/grafana";
      };
      services.prometheus = {
        enable = true;
        port = 9001;
        listenAddress = telv4;
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
            port = 9002;
          };
        };
        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [{
              targets = [ "${telv4}:9002" ];
            }];
          }
          {
            job_name = "otlp";
            static_configs = [{
              targets = [ "${telv4}:9003" ];
            }];
          }
        ];
      };
    }
    # {
    #   services.tempo = {
    #     enable = true;
    #     settings = {
    #       server = {
    #         http_listen_address = telv4;
    #         http_listen_port = 3200;
    #         grpc_listen_port = 9096;
    #       };
    #       distributor = {
    #         receivers = {
    #           otlp = {
    #             protocols = {
    #               http = { };
    #             };
    #           };
    #         };
    #       };
    #       storage.trace = {
    #         backend = "local";
    #         local.path = "/var/lib/tempo/traces";
    #         wal.path = "/var/lib/tempo/wal";
    #       };
    #       ingester = {
    #         lifecycler.ring.replication_factor = 1;
    #       };
    #     };
    #   };
    # }

    {
      services.loki =
        let
          inherit (config.services.loki) dataDir;
        in
        {
          enable = true;
          configuration = {
            # https://grafana.com/docs/loki/latest/configure/examples/configuration-examples/
            auth_enabled = false;
            server = {
              http_listen_address = telv4;
              http_listen_port = 3100;
              grpc_listen_address = telv4;
              grpc_listen_port = 9095;
            };

            common = {
              path_prefix = dataDir;
              replication_factor = 1;
              ring = {
                instance_addr = "127.0.0.1";
                kvstore.store = "inmemory";
              };
            };
            limits_config = {
              allow_structured_metadata = true;
            };

            schema_config = {
              configs = [
                {
                  from = "2024-08-29";
                  store = "tsdb";
                  object_store = "filesystem";
                  schema = "v13";
                  index = {
                    prefix = "index_";
                    period = "24h";
                  };
                }
              ];
            };

            ruler = {
              # external_url = "https://grafana.tigor.web.id";
              storage = {
                type = "local";
                local = {
                  directory = "${dataDir}/rules";
                };
              };
              rule_path = "/tmp/loki/rules"; # Temporary rule_path
            };

            compactor = {
              working_directory = "${dataDir}/retention";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };

            limits_config = {
              retention_period = "90d";
            };

            storage_config = {
              filesystem = {
                directory = "${dataDir}/chunks";
              };
            };
          };
        };
      # https://grafana.com/docs/grafana/latest/datasources/loki/
      services.grafana.provision.datasources.settings.datasources = [
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          access = "proxy";
          url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}";
          basicAuth = false;
          jsonData = {
            timeout = 60;
            maxLines = 1000;
          };
        }
      ];
      services.opentelemetry-collector = {
        settings = {
          # exporters."otlphttp/loki" = {
          #   endpoint = "http://${telv4}:${toString config.services.loki.configuration.server.http_listen_port}/otlp/v1/logs"; # loki
          # };
          # service.pipelines.logs = {
          #   receivers = [ "otlp" ];
          #   exporters = [ "otlphttp/loki" ];
          #   # exporters = ["prometheus"];
          # };
        };
      };
    }
    (
      let tserver = config.services.tempo.settings.server; in {
        services.tempo = {
          enable = true;
          settings = {
            server = {
              http_listen_address = telv4;
              #grpc_listen_address = telv4;
              http_listen_port = 3200;
              grpc_listen_port = 9096;
            };
            querier.frontend_worker.frontend_address = "${telv4}:9096";
            distributor = {
              receivers = {
                otlp = {
                  protocols = {
                    grpc = { endpoint = "${telv4}:4317"; };
                    http = { endpoint = "${telv4}:4318"; };
                  };
                };
              };
            };
            storage.trace = {
              backend = "local";
              local.path = "/var/lib/tempo/traces";
              wal.path = "/var/lib/tempo/wal";
            };
            ingester = {
              lifecycler.address = telv4;
              #lifecycler.ring.replication_factor = 1;
            };
          };
        };
        services.grafana.provision.datasources.settings.datasources = [
          {
            name = "Tempo";
            type = "tempo";
            access = "proxy";
            url = "http://${tserver.http_listen_address}:${toString tserver.http_listen_port}";
            basicAuth = false;
            jsonData = {
              nodeGraph.enabled = true;
              search.hide = false;
              traceQuery = {
                timeShiftEnabled = true;
                spanStartTimeShift = "1h";
                spanEndTimeShift = "1h";
              };
              spanBar = {
                type = "Tag";
                tag = "http.path";
              };
              tracesToLogsV2 = lib.mkIf true {
                datasourceUid = "loki";
                spanStartTimeShift = "-1h";
                spanEndTimeShift = "1h";
                tags = [ "job" "instance" "pod" "namespace" ];
                filterByTraceID = false;
                filterBySpanID = false;
                customQuery = true;
                query = ''method="$''${__span.tags.method}"'';
              };
            };
          }
        ];
        services.opentelemetry-collector = {
          settings = {
            exporters."otlphttp/tempo" = {
              endpoint = "http://${tserver.http_listen_address}:${toString tserver.http_listen_port}";
            };
            service.pipelines.traces = {
              receivers = [ "otlp" ];
              exporters = [ "otlphttp/tempo" ];
              # exporters = ["prometheus"];
            };
          };
        };
      }
    )
  ];
}
