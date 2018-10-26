defmodule Butters.PodWatch do
  @doc """
  Watches for a pod to finish whatever its supposed to do.

  TODO: handle when a pod errors out. Right now the GenServer will stay open until a successful exit.
  """

  use GenServer
  require Logger
  alias Kazan.Apis.Core.V1.Pod
  alias Kazan.Apis.Core.V1.PodStatus

  @impl GenServer
  def init(pod = %{namespace: namespace, name: name}) do
    Kazan.Apis.Core.V1.read_namespaced_pod_status!(namespace, name)
    |> Kazan.Watcher.start_link(send_to: self(), server: Butters.gke_server())

    {:ok, Map.put(pod, :phase, "Pending")}
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{type: :gone}, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{object: %Pod{status: %PodStatus{phase: phase}}, type: :modified}, state = %{name: name}) do
    Logger.debug("Pod #{name} is #{phase}")

    {:noreply, Map.put(state, :phase, phase)}
  end

  @impl GenServer
  def handle_info(%Kazan.Watcher.Event{object: object, type: type}, state) do
    Logger.debug("Pod event #{type}: #{inspect(object)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:phase, _from, state = %{phase: phase}) do
    {:reply, phase, state}
  end

  @doc """
  Start a watch on a given pod and wait for it to finish, returning any logs from the pod.
  """
  def wait_for_completion(pod_metadata) do
    {:ok, pid} = GenServer.start_link(__MODULE__, pod_metadata)
    _wait_for_completion(pid, pod_metadata)
  end

  defp _wait_for_completion(pid, metadata) do
    case GenServer.call(pid, :phase) do
      "Running" -> _wait_for_completion(pid, metadata)
      "Pending"-> _wait_for_completion(pid, metadata)
      "Succeeded" -> {:ok, Butters.get_logs(metadata)}
      "Failed" -> {:error, Butters.get_logs(metadata)}
    end
  end
end
