defmodule Ms2ex.Managers.GlobalCounter do
  use Agent

  @counter 10_000_000

  def start_link(_args \\ []) do
    Agent.start_link(fn -> @counter end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, & &1)
  end

  def get_and_increment do
    Agent.get_and_update(__MODULE__, &{&1, &1 + 1})
  end
end
