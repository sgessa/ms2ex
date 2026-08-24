defmodule Ms2ex.Managers.GlobalCounter do
  use Agent

  # app-wide id space for mounts; must stay clear of the per-field ranges
  # used for players (10M+), npcs/portals (50M+) and items (300M+)
  @counter 500_000_000

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
