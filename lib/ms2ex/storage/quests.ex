defmodule Ms2ex.Storage.Quests do
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @doc """
  Retrieves quest metadata by quest ID.
  """
  def get_meta(quest_id) do
    Storage.get(:quest, quest_id)
  end

  @doc """
  Retrieves all quest metadata.
  """
  def get_all() do
    # TODO
    []
  end

  @doc """
  Retrieves quests by NPC ID.
  Returns quests where the NPC is either the start or complete NPC.
  """
  def get_quests_by_npc(npc_id) do
    get_all()
    |> Enum.filter(fn quest ->
      get_in(quest, [:basic, :complete_npc]) == npc_id
    end)
  end

  @doc """
  Retrieves quests by type.
  """
  def get_quests_by_type(type) do
    get_all()
    |> Enum.filter(fn quest ->
      get_in(quest, [:basic, :type]) == type
    end)
  end

  @doc """
  Retrieves quests by chapter.
  """
  def get_quests_by_chapter(chapter_id) do
    get_all()
    |> Enum.filter(fn quest ->
      get_in(quest, [:basic, :chapter_id]) == chapter_id
    end)
  end

  @doc """
  Determines if a quest is an account quest based on its metadata.
  """
  @spec account_quest?(map()) :: boolean()
  def account_quest?(quest) do
    get_in(quest, [:basic, :account]) > 0
  end

  @doc """
  Gets the owner ID for a quest based on whether it is an account quest or character quest.
  """
  @spec get_owner_id(Schema.Character.t(), map()) :: binary()
  def get_owner_id(character, quest) do
    if Storage.Quests.account_quest?(quest) do
      character.account_id
    else
      character.id
    end
  end
end
