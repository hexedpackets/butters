defmodule Butters do
  @moduledoc """
  Documentation for Butters.
  """

  require Logger
  alias Kazan.Apis.Core.V1.Pod
  alias Kazan.Models.Apimachinery.Meta.V1.ObjectMeta

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

  @doc """
  Create the NodeAddinity object based on the runtime config.
  """
  def node_affinity() do
    expressions = Application.get_env(:butters, :node_affinity_blacklist)
    |> Enum.map(fn label -> %Kazan.Apis.Core.V1.NodeSelectorRequirement{key: label, operator: "DoesNotExist"} end)
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
  def run_pod(container, name, node_name \\ nil) do
    Logger.debug("Running pod #{name} on node #{node_name}")
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
        node_name: node_name,
        service_account_name: Application.get_env(:butters, :service_account_name),
        restart_policy: "Never",
      }
    }
    |> Kazan.Apis.Core.V1.create_namespaced_pod!(namespace)
    |> run!()
  end

  def get_logs(%{name: name, namespace: namespace}) do
    Kazan.Apis.Core.V1.read_namespaced_pod_log!(namespace, name) |> run!()
  end

  def delete_pod(%{name: name, namespace: namespace}) do
    %Kazan.Models.Apimachinery.Meta.V1.DeleteOptions{}
    |> Kazan.Apis.Core.V1.delete_namespaced_pod!(namespace, name)
    |> run!()
  end

  @doc """
  Find all nodes available for chaosing.
  """
  def all_nodes() do
    Kazan.Apis.Core.V1.list_node!()
    |> run!()
    |> Map.get(:items)
    |> Stream.filter(&node_filter/1)
    |> Enum.map(fn %{metadata: %{name: name}} -> name end)
  end

  @doc """
  Select a node to mess up with chaos.
  """
  def select_random_node() do
    all_nodes() |> Enum.random()
  end

  @doc """
  Determine the IP address of the kubernetes master.
  """
  def get_master_ip() do
    result = Kazan.Apis.Core.V1.read_namespaced_endpoints!("default", "kubernetes") |> run!()

    case result do
      %{subsets: [%{addresses: [%{ip: addr}]}]} -> {:ok, addr}
      _ -> {:error, :unknown}
    end
  end

  defp node_filter(%Kazan.Apis.Core.V1.Node{metadata: %ObjectMeta{labels: labels}}) do
    Application.get_env(:butters, :node_affinity_blacklist)
    |> Enum.any?(fn ignore_label -> Map.has_key?(labels, ignore_label) end)
    |> Kernel.not()
  end
end
