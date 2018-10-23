use Mix.Config

config :butters, :iptables_image, "vimagick/iptables:latest"
config :butters, :namespace, "chaos"
config :butters, :service_account_name, nil
# will be used as a requiredDuringSchedulingIgnoredDuringExecution affinity
# https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature
config :butters, :node_affinity_blacklist, [
  "butters/ignore"
]
config :butters, :traffic_profile, [
  slow: "delay 75ms 100ms distribution normal"
]

config :butters, :device, "eth0"

import_config "#{Mix.env()}.exs"
