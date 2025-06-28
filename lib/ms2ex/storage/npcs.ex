defmodule Ms2ex.Storage.Npcs do
  alias Ms2ex.Storage

  def get_meta(id) do
    Storage.get(:npc, id)
  end
end
