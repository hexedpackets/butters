use Mix.Config

config :butters, :iptables_image, "vimagick/iptables:latest"
config :butters, :namespace, "chaos"
config :butters, :service_account_name, nil
# will be used as a requiredDuringSchedulingIgnoredDuringExecution affinity
# https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature
config :butters, :node_affinity, [
  %{key: "butters/ignore", operator: "DoesNotExist"}
]

import_config "#{Mix.env()}.exs"
