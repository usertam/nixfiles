{ config, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    enabledCollectors = [
      "systemd" "processes" "ethtool" "qdisc" "softirqs" "buddyinfo" "sysctl" "swap"
    ];
  };

  services.vmagent = {
    enable = true;

    remoteWrite = {
      url = "https://prometheus-prod-37-prod-ap-southeast-1.grafana.net/api/prom/push";
      basicAuthUsername = "3380546";
      basicAuthPasswordFile = "/var/lib/vmagent/grafana-prom-token";
    };

    prometheusConfig = {
      global = {
        scrape_interval = "60s";
        scrape_timeout = "10s";
        external_labels = {
          host = config.networking.hostName;
        };
      };

      scrape_configs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "127.0.0.1:9100" ];
              labels.instance = config.networking.hostName;
            }
          ];
          metric_relabel_configs = [
            # Drop internal Go runtime and promhttp series.
            {
              source_labels = [ "__name__" ];
              regex = "(go|promhttp)_.*";
              action = "drop";
            }
            # Drop some systemd unit states to reduce series count.
            {
              source_labels = [ "__name__" "state" ];
              regex = "node_systemd_unit_state;(activating|deactivating|inactive)";
              action = "drop";
            }
          ];
        }
      ];
    };

    extraArgs = [
      # Module leaves vmagent's own HTTP listener on :8429 all-interfaces.
      "-httpListenAddr=127.0.0.1:8429"

      # Bound the per-endpoint disk spool (outage tolerance vs disk). At
      # one-node scale, 1GiB of compressed pending blocks is days of outage.
      "-remoteWrite.maxDiskUsagePerURL=1GiB"
    ];
  };

  # The token lives on tmpfs and is deployed out-of-band, so it may not
  # exist at boot. Skip starting until it does, then let the path unit
  # start vmagent the moment the key lands.
  systemd.services.vmagent.unitConfig.ConditionPathExists =
    config.services.vmagent.remoteWrite.basicAuthPasswordFile;

  systemd.paths.vmagent = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists =
      config.services.vmagent.remoteWrite.basicAuthPasswordFile;
  };
}
