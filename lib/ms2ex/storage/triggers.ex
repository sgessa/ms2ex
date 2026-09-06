defmodule Ms2ex.Storage.Triggers do
  @moduledoc """
  Per-map trigger scripts, keyed by the map's xblock name. Each document
  holds every script of the xblock: states with on-enter/on-exit actions
  plus ordered conditions carrying their transition target.
  """

  alias Ms2ex.Storage

  @spec get_scripts(String.t() | nil) :: map()
  def get_scripts(xblock)

  def get_scripts(xblock) when is_binary(xblock) do
    case Storage.get(:trigger, xblock) do
      %{scripts: scripts} when is_map(scripts) -> scripts
      _ -> %{}
    end
  end

  def get_scripts(_xblock), do: %{}
end
