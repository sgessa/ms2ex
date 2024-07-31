defmodule Ms2ex.Storage.Maps do
  alias Ms2ex.Storage
  alias Ms2ex.Structs

  def get_bounds(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:boundings)
    |> hd()
    |> Map.get(:block)
  end

  def get_spawn(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:pc_spawns)
    |> Enum.filter(&Map.get(&1.block, :enable))
    |> Enum.random()
    |> Map.get(:block)
  end

  def get_npcs(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:npc_spawns)
    |> Enum.flat_map(fn %{block: block} ->
      Enum.flat_map(block.npc_list, fn npc ->
        Enum.map(1..npc.count, fn _ ->
          block_attrs =
            Map.take(block, [
              :position,
              :visible,
              :rotation,
              :regen_check_time,
              :spawn_on_field_create
            ])

          npc =
            Map.new()
            |> Map.put(:id, npc.npc_id)
            |> Map.merge(block_attrs)
            |> Map.put(:metadata, Storage.Npcs.get_meta(npc.npc_id))
            |> Map.put(:spawn, block.position)
            |> Map.put(:type, :npc)
            |> Map.put_new(:rotation, %Structs.Coord{})

          npc
          |> Map.put(:animation, "123")
        end)
      end)
    end)
    |> Enum.reject(&is_nil(&1.metadata))
  end

  def get_meta(field_id) do
    Storage.get(:map, field_id)
  end
end
