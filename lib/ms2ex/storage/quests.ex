defmodule Ms2ex.Storage.Quests do
  alias Ms2ex.Context
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

  @doc """
  Checks if a character meets the requirements for a quest.
  """
  @spec meet_level_req?(Schema.Character.t(), map()) :: boolean()
  def meet_level_req?(character, metadata) do
    req_level = get_in(metadata, [:require, :level]) || 0
    max_level = get_in(metadata, [:require, :max_level]) || 0

    if req_level > 0 && character.level < req_level do
      false
    else
      max_level == 0 || character.level <= max_level
    end
  end

  @doc """
  Checks if a character meets the job requirements for a quest.
  """
  @spec meet_job_req?(Schema.Character.t(), map()) :: boolean()
  def meet_job_req?(character, metadata) do
    job_codes = get_in(metadata, [:require, :job]) || []
    Enum.empty?(job_codes) || Enum.member?(job_codes, character.job.job_code)
  end

  @doc """
  Checks if a character meets the quests requirement for a quest.
  """
  @spec meet_quests_req?(Schema.Character.t(), map()) :: boolean()
  def meet_quests_req?(character, metadata)

  def meet_quests_req?(_character, %{require: %{quest: []}}) do
    true
  end

  def meet_quests_req?(character, %{require: %{quest: pre_quests}}) do
    Enum.all?(pre_quests, fn quest_id ->
      Context.Quests.has_completed_quest?(character, quest_id)
    end)
  end

  @doc """
  TODO: Checks if a character meets the gear score requirement for a quest.
  """
  @spec meet_gear_score_req?(Schema.Character.t(), map()) :: boolean()
  def meet_gear_score_req?(_character, _metadata) do
    true
  end

  @doc """
  TODO: Checks if a character meets the achievement requirement for a quest.
  """
  @spec meet_achievement_req?(Schema.Character.t(), map()) :: boolean()
  def meet_achievement_req?(_character, _metadata) do
    true
  end

  @doc """
  Checks if a character meets the selectable quests requirement for a quest.
  """
  def meet_selectable_quests_req?(character, metadata)

  def meet_selectable_quests_req?(_character, %{require: %{selectable_quest: []}}) do
    true
  end

  def meet_selectable_quests_req?(character, %{require: %{selectable_quest: quests}}) do
    Enum.any?(quests, fn quest_id ->
      Context.Quests.has_completed_quest?(character, quest_id)
    end)
  end
end
