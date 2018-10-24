defmodule Butters.PodWatch do
  @doc """
  Watches for a pod to finish whatever its supposed to do.

  TODO: handle when a pod errors out. Right now the GenServer will stay open until a successful exit.
  """

  use GenServer
  require Logger
  alias Kazan.Apis.Core.V1.Pod
  alias Kazan.Apis.Core.V1.PodStatus
  alias Kazan.Models.Apimachinery.Meta.V1.ObjectMeta

  @impl GenServer
  def init(pod = %{namespace: namespace, name: name}) do
    Kazan.Apis.Core.V1.read_namespaced_pod_status!(namespace, name)
    |> Kazan.Watcher.start_link(send_to: self(), server: Butters.gke_server())

    {:ok, pod}
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{type: :gone}, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{object: %Pod{status: %PodStatus{phase: phase}}, type: :modified}, state = %{name: name}) do
    Logger.debug("Pod #{name} is #{phase}")

    case phase do
      "Running" -> {:noreply, state}
      "Succeeded" -> {:stop, :normal, state}
      "Failed" -> {:stop, :pod_failure, state}
    end
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{object: object, type: type}, state) do
    Logger.debug("Pod event #{type}: #{inspect(object)}")
    {:noreply, state}
  end

  @doc """
  Start a watch on a given pod and wait for it to finish.
  """
  def wait_for_completion(pod = %Pod{metadata: %ObjectMeta{name: name, namespace: namespace}}) do
    {:ok, pid} = GenServer.start_link(__MODULE__, %{name: name, namespace: namespace})

    # Wait until the GenServer exits.
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, _, _, _} -> nil
    end

    pod
  end
end
