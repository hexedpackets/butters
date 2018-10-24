defmodule Mix.Tasks.Butters.Restore do
  use Mix.Task

  @shortdoc "Restore a node after punishing it with chaos."

  @moduledoc """
  Restore a node after punishing it with chaos.

  `mix butters.restore NODE` will restore the specified node.

  `mix butters.restore` will restore all nodes in the cluster.
  """

  @doc """
  Restores a specific node.
  """
  def run([name]) do
    Butters.Network.restore(name)
  end

  @doc """
  Restore all nodes in the cluster.
  """
  def run([]) do
    Butters.Network.restore_all()
  end
end
