defmodule Butters do
  @moduledoc """
  Documentation for Butters.
  """

  require Logger
  alias Kazan.Apis.Core.V1.Pod
  alias Kazan.Models.Apimachinery.Meta.V1.ObjectMeta

  @container_security_context %Kazan.Apis.Core.V1.SecurityContext{privileged: true}
  @minimal_resources %Kazan.Apis.Core.V1.ResourceRequirements{limits: %{cpu: "50m", memory: "64Mi"}, requests: %{cpu: "50m", memory: "64Mi"}}

  @doc """
  Create a Kazan server object that is authenticated with gcloud.
  """
  def gke_server() do
    "~/.kube/config"
    |> Path.expand
    |> Kazan.Server.from_kubeconfig()
    |> Kazan.Server.resolve_auth!(allow_command_execution: true)
  end

  @doc """
  Shortcut for `Kazan.run/2` using the default GKE server.
  """
  def run!(request) do
     Kazan.run!(request, server: Butters.gke_server())
  end

  def run_iptables(command) when is_binary(command), do: run_iptables([command])
  def run_iptables(command) do
    pod = iptables_container(command)
    |> run_pod("iptables")
    |> Butters.PodWatch.wait_for_completion()

    logs = get_logs(pod)
    delete_pod(pod)

    logs
  end

  @doc """
  Create the NodeAddinity object based on the runtime config.
  """
  def node_affinity() do
    expressions = Application.get_env(:butters, :node_affinity)
    |> Enum.map(fn aff -> struct(Kazan.Apis.Core.V1.NodeSelectorRequirement, aff) end)
    terms = [%Kazan.Apis.Core.V1.NodeSelectorTerm{match_expressions: expressions}]

    %Kazan.Apis.Core.V1.Affinity{
      node_affinity: %Kazan.Apis.Core.V1.NodeAffinity{
        required_during_scheduling_ignored_during_execution: %Kazan.Apis.Core.V1.NodeSelector{node_selector_terms: terms}
      }
    }
  end

  @doc """
  Run a single-container pod in the kubernetes cluster. All containers run in the same namespace.
  """
  def run_pod(container, name) do
    Logger.debug("Running pod #{name}")
    namespace = Application.get_env(:butters, :namespace)

    %Pod{
      metadata: %ObjectMeta{
        labels: %{
          app: "butters",
        },
        name: name,
      },
      spec: %Kazan.Apis.Core.V1.PodSpec{
        affinity: node_affinity(),
        containers: [container],
        host_network: true,
        service_account_name: Application.get_env(:butters, :service_account_name),
        restart_policy: "Never",
      }
    }
    |> Kazan.Apis.Core.V1.create_namespaced_pod!(namespace)
    |> run!()
  end

  @doc """
  Create a Container object for running iptables commands.
  """
  def iptables_container(command) do
    %Kazan.Apis.Core.V1.Container{
      security_context: @container_security_context,
      command: command,
      image: Application.get_env(:butters, :iptables_image),
      name: "iptables",
      resources: @minimal_resources,
    }
  end

  def get_logs(%Pod{metadata: %ObjectMeta{name: name, namespace: namespace}}) do
    Kazan.Apis.Core.V1.read_namespaced_pod_log!(namespace, name) |> run!()
  end

  def delete_pod(%Pod{metadata: %ObjectMeta{name: name, namespace: namespace}}) do
    %Kazan.Models.Apimachinery.Meta.V1.DeleteOptions{}
    |> Kazan.Apis.Core.V1.delete_namespaced_pod!(namespace, name)
    |> run!()
  end

  @doc """
  Select a node to mess up with chaos.
  """
  def select_random_node() do
    Kazan.Apis.Core.V1.list_node!()
    |> run!()
    |> Map.get(:items)
    |> Enum.random()
    |> Map.get(:metadata)
    |> Map.get(:name)
  end
end
