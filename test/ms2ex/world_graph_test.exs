defmodule Ms2ex.Context.WorldGraphTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Context.WorldGraph

  test "finds a taxi route through the initialized world graph" do
    assert {:ok, path, count} = WorldGraph.get_shortest_path(2_000_062, 2_000_001)
    assert List.first(path) == 2_000_062
    assert List.last(path) == 2_000_001
    assert count == length(path)
  end
end
