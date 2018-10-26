defmodule Butters.Network do
  @moduledoc """
  Control the network, control the world.

  Functions for making things slower, more errory, partitioned, etc.
  """

  require Logger

  @master_traffic_class "1:1"
  @default_traffic_class "1:2"

  @doc """
  Create a Container object for running iptables commands.
  """
  def iptables_container(command) do
    %Kazan.Apis.Core.V1.Container{
      security_context: %Kazan.Apis.Core.V1.SecurityContext{privileged: true},
      command: command,
      image: Application.get_env(:butters, :iptables_image),
      name: "iptables",
      resources: %Kazan.Apis.Core.V1.ResourceRequirements{limits: %{cpu: "50m", memory: "64Mi"}, requests: %{cpu: "50m", memory: "64Mi"}},
    }
  end

  @doc """
  Run a traffic control command on a specific node, returning the logs when it exits.
  """
  def run_pod(command, name, node) do
    Logger.debug("Running #{inspect(command)} on #{node}")

    pod = command
    |> iptables_container()
    |> Butters.run_pod("iptables-#{name}", node)
    |> Map.get(:metadata)

    result = Butters.PodWatch.wait_for_completion(pod)
    Butters.delete_pod(pod)

    result
  end

  @doc """
  Set a traffic profile on a given node, likely causing pagers to light up as applications scream in pain.
  """
  def cause_chaos(profile, node) do
    Logger.info("Running the #{profile} profile on #{node}")

    profile
    |> net_config()
    |> net_command(net_device())
    |> run_pod(profile, node)
  end

  def cause_controlled_chaos(profile, node) do
    Logger.info("Running the #{profile} profile on the control plane of #{node}")

    filter_control_plane(node)

    profile
    |> net_config()
    |> net_command(net_device(), @master_traffic_class)
    |> run_pod(profile, node)
  end

  @doc """
  Removes all rules for a node to hopefully restore it to normal operation. But can Chaos truly be tamed?
  """
  def restore(node) do
    Logger.info("Restoring network for #{node}")

    # This can exit with "RTNETLINK answers: No such file or directory" if there are no rules set, which is fine.
    result = ["tc", "qdisc", "del", "dev", net_device(), "root"] |> run_pod("restore-#{node}", node)
    case result do
      {:error, "RTNETLINK answers: No such file or directory\n"} -> {:ok, "Node is in default state"}
      _ -> result
    end
  end

  @doc """
  Setup filtering for traffic between the kubelet and the master while leaving everything else untouched.
  """
  def filter_control_plane(node) do
    dev = net_device()
    {:ok, master_ip} = Butters.get_master_ip()
    priority_qdisc = "tc qdisc replace dev eth0 root handle 1: prio"
    master_filter = "tc filter add dev #{dev} protocol ip parent 1: prio 1 u32 match ip dst #{master_ip}/32 flowid #{@master_traffic_class}"
    default_filter = "tc filter add dev #{dev} protocol all parent 1: prio 2 u32 match u32 0 0 flowid #{@default_traffic_class}"

    ["sh", "-c", Enum.join([priority_qdisc, master_filter, default_filter], " && ")]
    |> run_pod("master-filter-#{node}", node)
  end

  @doc """
  Restore every node in the cluster
  """
  def restore_all() do
    {_, failed} = Butters.all_nodes()
    |> Enum.map_reduce(%{}, fn node, acc ->
      IO.inspect(acc, label: "acc")
      result = restore(node)
      case resu

      lt do
        {:ok, _} -> {result, acc}
        {:error, logs} -> {result, Map.put(acc, node, logs)} |> IO.inspect(label: "updated")
      end
    end)

    if failed == %{} do
      :ok
    else
      {:error, failed}
    end
  end

  def random_slow() do
    node = Butters.select_random_node()
    cause_chaos(:slow, node)
  end

  defp net_command(params, device, parent \\ "root"), do: ["tc", "qdisc", "add", "dev", device, "parent", parent, "netem" | params]
  defp net_config(profile), do: Application.get_env(:butters, :traffic_profile) |> Keyword.get(profile) |> String.split()

  # TODO: find the device from the node instead of assuming it from the config
  defp net_device(), do: Application.get_env(:butters, :device)
end
