defmodule Ms2ex.Storage.Tables.InstanceFields do
  @moduledoc """
  Instance-field table: maps that are instanced rather than shared.
  `solo` maps (tutorials, quest instances) allocate a private field per
  entry; `channel_scale` maps share one field per channel. Maps absent
  from the table are ordinary shared fields.
  """

  alias Ms2ex.Storage

  @table_name "server.instancefield.xml"

  @doc "Instance doc for a map (`:type`, `:instance_id`, `:pool_count`,
  `:max_count`, `:save_field`, `:npc_stat_factor_id`), or nil when the
  map is not instanced."
  @spec get(integer()) :: map() | nil
  def get(map_id) do
    case Storage.get(:table, @table_name) do
      %{} = fields -> Map.get(fields, map_id)
      _ -> nil
    end
  end

  @doc "Whether the map is instanced at all (any instance type)."
  @spec instanced?(integer()) :: boolean()
  def instanced?(map_id), do: get(map_id) != nil

  @doc "Whether the map allocates a private field instance per entry."
  @spec solo?(integer()) :: boolean()
  def solo?(map_id) do
    case get(map_id) do
      %{type: :solo} -> true
      _ -> false
    end
  end
end
