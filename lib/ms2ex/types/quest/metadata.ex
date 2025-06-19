defmodule Ms2ex.Types.Quest.Metadata do
  @moduledoc """
  Defines the structure of quest metadata.
  Ported from Maple2's QuestMetadata.cs
  """

  defmodule Basic do
    @moduledoc """
    Basic quest information.
    """

    defstruct [
      :id,
      :name,
      :type,
      :chapter_id,
      :quest_icon,
      :disabled,
      :account,
      :event_tag,
      :complete_npc,
      :forfeitable,
      :auto_start,
      :use_postbox,
      :complete_maps,
      progress_maps: []
    ]
  end

  defmodule Require do
    @moduledoc """
    Quest requirements.
    """

    defstruct [
      :level,
      :max_level,
      :gear_score,
      :achievement,
      :unrequired_achievement,
      job: [],
      quest: [],
      selectable_quest: []
    ]
  end

  defmodule RemoteAccept do
    @moduledoc """
    Remote quest accept configuration.
    """

    defstruct [:type, :map_id]
  end

  defmodule RemoteComplete do
    @moduledoc """
    Remote quest completion configuration.
    """

    defstruct [:type, :map_id, :npc_id]
  end

  defmodule Reward do
    @moduledoc """
    Quest reward information.
    """

    defmodule Item do
      @moduledoc """
      Quest item reward.
      """

      defstruct [:id, :rarity, :amount]
    end

    defstruct [
      :exp,
      :meso,
      :treva,
      :rue,
      :contribution,
      :guild_coin,
      :guild_exp,
      essential_items: [],
      essential_job_items: [],
      selective_items: []
    ]
  end

  defmodule GoToNpc do
    @moduledoc """
    Go to NPC quest configuration.
    """

    defstruct [:enabled, :map_id, :portal_id]
  end

  defmodule Dispatch do
    @moduledoc """
    Quest dispatch configuration.
    """

    defstruct [:map_id, :portal_id]
  end

  defmodule SummonPortal do
    @moduledoc """
    Portal summoning configuration.
    """

    defstruct [:portal_id, :map_id, :lifetime, :scale_x, :scale_y]
  end

  defmodule ConditionMetadata do
    @moduledoc """
    Quest condition metadata.
    """

    defstruct [
      :type,
      :value,
      :item_id,
      :npc_id,
      :level,
      :required_quest_id,
      :object_id,
      monster_ids: []
    ]
  end

  defstruct [
    :id,
    :basic,
    :require,
    :remote_accept,
    :remote_complete,
    :accept_reward,
    :complete_reward,
    :go_to_npc,
    :dispatch,
    :summon_portal,
    :event_mission_type,
    :repeatable,
    :mentoring,
    conditions: []
  ]

  @doc """
  Creates a new quest metadata instance from raw data.
  """
  def new(data) do
    %__MODULE__{
      id: Map.get(data, :id),
      basic: parse_basic(Map.get(data, :basic, %{})),
      require: parse_require(Map.get(data, :require, %{})),
      remote_accept: parse_remote_accept(Map.get(data, :remote_accept, %{})),
      remote_complete: parse_remote_complete(Map.get(data, :remote_complete, %{})),
      accept_reward: parse_reward(Map.get(data, :accept_reward, %{})),
      complete_reward: parse_reward(Map.get(data, :complete_reward, %{})),
      go_to_npc: parse_go_to_npc(Map.get(data, :go_to_npc, %{})),
      dispatch: parse_dispatch(Map.get(data, :dispatch, %{})),
      summon_portal: parse_summon_portal(Map.get(data, :summon_portal, %{})),
      event_mission_type: Map.get(data, :event_mission_type, :none),
      repeatable: Map.get(data, :repeatable, false),
      mentoring: Map.get(data, :mentoring),
      conditions: parse_conditions(Map.get(data, :conditions, []))
    }
  end

  defp parse_basic(data) do
    %Basic{
      id: Map.get(data, :id),
      name: Map.get(data, :name, ""),
      type: Map.get(data, :type, :epic_quest),
      chapter_id: Map.get(data, :chapter_id, 0),
      quest_icon: Map.get(data, :quest_icon, ""),
      disabled: Map.get(data, :disabled, false),
      account: Map.get(data, :account, 0),
      event_tag: Map.get(data, :event_tag, ""),
      complete_npc: Map.get(data, :complete_npc, 0),
      forfeitable: Map.get(data, :forfeitable, true),
      auto_start: Map.get(data, :auto_start, false),
      use_postbox: Map.get(data, :use_postbox, false),
      complete_maps: Map.get(data, :complete_maps),
      progress_maps: Map.get(data, :progress_maps, [])
    }
  end

  defp parse_require(data) do
    %Require{
      level: Map.get(data, :level, 0),
      max_level: Map.get(data, :max_level, 0),
      gear_score: Map.get(data, :gear_score, 0),
      achievement: Map.get(data, :achievement, 0),
      unrequired_achievement: Map.get(data, :unrequired_achievement, {0, 0}),
      job: Map.get(data, :job, []),
      quest: Map.get(data, :quest, []),
      selectable_quest: Map.get(data, :selectable_quest, [])
    }
  end

  defp parse_remote_accept(data) do
    %RemoteAccept{
      type: Map.get(data, :type, 0),
      map_id: Map.get(data, :map_id, 0)
    }
  end

  defp parse_remote_complete(data) do
    %RemoteComplete{
      type: Map.get(data, :type, 0),
      map_id: Map.get(data, :map_id, 0),
      npc_id: Map.get(data, :npc_id, 0)
    }
  end

  defp parse_reward(data) do
    %Reward{
      exp: Map.get(data, :exp, 0),
      meso: Map.get(data, :meso, 0),
      treva: Map.get(data, :treva, 0),
      rue: Map.get(data, :rue, 0),
      contribution: Map.get(data, :contribution, 0),
      guild_coin: Map.get(data, :guild_coin, 0),
      guild_exp: Map.get(data, :guild_exp, 0),
      essential_items: parse_items(Map.get(data, :essential_items, [])),
      essential_job_items: parse_items(Map.get(data, :essential_job_items, [])),
      selective_items: parse_items(Map.get(data, :selective_items, []))
    }
  end

  defp parse_items(items) do
    Enum.map(items, fn item_data ->
      %Reward.Item{
        id: Map.get(item_data, :id, 0),
        rarity: Map.get(item_data, :rarity, 0),
        amount: Map.get(item_data, :amount, 1)
      }
    end)
  end

  defp parse_go_to_npc(data) do
    %GoToNpc{
      enabled: Map.get(data, :enabled, false),
      map_id: Map.get(data, :map_id, 0),
      portal_id: Map.get(data, :portal_id, 0)
    }
  end

  defp parse_dispatch(data) do
    %Dispatch{
      map_id: Map.get(data, :map_id, 0),
      portal_id: Map.get(data, :portal_id, 0)
    }
  end

  defp parse_summon_portal(data) do
    if Enum.empty?(data) do
      nil
    else
      %SummonPortal{
        portal_id: Map.get(data, :portal_id, 0),
        map_id: Map.get(data, :map_id, 0),
        lifetime: Map.get(data, :lifetime, 0),
        scale_x: Map.get(data, :scale_x, 1.0),
        scale_y: Map.get(data, :scale_y, 1.0)
      }
    end
  end

  defp parse_conditions(conditions) do
    Enum.map(conditions, fn condition_data ->
      %ConditionMetadata{
        type: Map.get(condition_data, :type, :none),
        value: Map.get(condition_data, :value, 0),
        item_id: Map.get(condition_data, :item_id, 0),
        npc_id: Map.get(condition_data, :npc_id, 0),
        level: Map.get(condition_data, :level, 0),
        required_quest_id: Map.get(condition_data, :required_quest_id, 0),
        object_id: Map.get(condition_data, :object_id, 0),
        monster_ids: Map.get(condition_data, :monster_ids, [])
      }
    end)
  end
end
