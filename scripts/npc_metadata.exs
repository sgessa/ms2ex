npc_id =
  case System.argv() do
    [arg | _] -> String.to_integer(arg)
    [] -> nil
  end

:ets.new(:metadata, [:named_table, :set, :public, read_concurrency: true])
{:ok, _} = Redix.start_link("redis://localhost:6379", name: Ms2ex.Redix)

defmodule NpcMeta do
  def print(npc_id) do
    case Ms2ex.Storage.get(:npc, npc_id) do
      nil ->
        IO.puts("npc #{npc_id} not found in metadata")

      npc ->
        basic = get_in(npc, [:basic]) || %{}
        boss? = (basic[:friendly] || 0) == 0 && (basic[:class] || 0) >= 3

        IO.puts("npc #{npc_id} — #{get_in(npc, [:model, :name])}")
        IO.puts(
          "level=#{basic[:level]} friendly=#{basic[:friendly]} class=#{basic[:class]} boss?=#{boss?}"
        )

        IO.puts("custom_exp: #{inspect(get_in(npc, [:basic, :custom_exp]))}")
        IO.inspect(get_in(npc, [:corpse]), label: "corpse")
        IO.inspect(get_in(npc, [:dead]), label: "dead")
        IO.inspect(get_in(npc, [:drop_info]), label: "drop_info")
    end
  end

  # walks every npc document and returns the id of the first one whose
  # corpse section exists (the ingest only writes it when hitAble=1)
  def find_hittable_corpse do
    stream_keys("0")
  end

  defp stream_keys(cursor) do
    {:ok, [next, keys]} = Redix.command(Ms2ex.Redix, ["SCAN", cursor, "MATCH", "npc:*", "COUNT", 500])

    ids =
      Enum.flat_map(keys, fn
        <<"npc:", id::binary>> -> [String.to_integer(id)]
        _ -> []
      end)

    hit =
      Enum.find(ids, fn id ->
        npc = Ms2ex.Storage.get(:npc, id)
        get_in(npc || %{}, [:corpse, :hit_able]) == true
      end)

    if hit do
      hit
    else
      if next == "0" do
        :none
      else
        stream_keys(next)
      end
    end
  end
end

if npc_id do
  NpcMeta.print(npc_id)
else
  IO.puts("scanning npcs for a corpse-hittable mob ...")

  case NpcMeta.find_hittable_corpse() do
    :none -> IO.puts("no npc has a hittable corpse")
    id ->
      IO.puts("found:")
      NpcMeta.print(id)
  end
end
