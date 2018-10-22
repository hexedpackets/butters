defmodule ButtersTest do
  use ExUnit.Case
  doctest Butters

  test "greets the world" do
    assert Butters.hello() == :world
  end
end
