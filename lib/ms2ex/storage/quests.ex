defmodule Ms2ex.Storage.Quests do
  alias Ms2ex.Storage

  def get_meta(quest_id) do
    Storage.get(:quest, quest_id)
  end
end
