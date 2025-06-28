defmodule Ms2ex.Packets.Game.Quest do
  import Ms2ex.Packets.PacketWriter

  @error 0x00
  @talk 0x01
  @start 0x02
  @update 0x03
  @complete 0x04
  @unknown5 0x05
  @abandon 0x06
  @expired 0x07
  @set_tracking 0x09
  @summon_portal 0x12
  @exploration_progress 0x15
  @load_quest_states 0x16
  @load_quests 0x17
  @unknown25 0x19
  @exploration_reward 0x1A
  @unknown30 0x1E
  @daily_reputation_missions 0x1F
  @weekly_reputation_missions 0x20
  @alliance_accept 0x22
  @alliance_complete 0x23
  @unknown38 0x26

  def error(error_code) do
    __MODULE__
    |> build()
    |> put_byte(@error)
    |> put_int(error_code)
  end

  def talk(npc_object_id, quests) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@talk)
      |> put_int(npc_object_id)
      |> put_int(Enum.count(quests))

    Enum.reduce(quests, packet, fn quest, packet ->
      put_int(packet, quest.id)
    end)
  end

  def start(quest) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@start)
      |> put_int(quest.quest_id)
      |> put_long(quest.start_time)
      |> put_bool(quest.track)
      |> put_int(map_size(quest.conditions))

    Enum.reduce(quest.conditions, packet, fn {_index, condition}, packet ->
      put_int(packet, condition.counter)
    end)
  end

  def update(quest) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@update)
      |> put_int(quest.quest_id)
      |> put_int(map_size(quest.conditions))

    Enum.reduce(quest.conditions, packet, fn {_index, condition}, packet ->
      put_int(packet, condition.counter)
    end)
  end

  def complete(quest) do
    __MODULE__
    |> build()
    |> put_byte(@complete)
    |> put_int(quest.quest_id)
    # quest.state
    |> put_int(1)
    |> put_long(quest.end_time)
  end

  def unknown5 do
    __MODULE__
    |> build()
    |> put_byte(@unknown5)
    |> put_int(0)
    |> put_int(0)
  end

  def abandon(quest_id) do
    __MODULE__
    |> build()
    |> put_byte(@abandon)
    |> put_int(quest_id)
  end

  def expired(quest_ids) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@expired)
      |> put_int(Enum.count(quest_ids))

    Enum.reduce(quest_ids, packet, fn quest_id, packet ->
      put_int(packet, quest_id)
    end)
  end

  def set_tracking(quest_id, tracked) do
    __MODULE__
    |> build()
    |> put_byte(@set_tracking)
    |> put_int(quest_id)
    |> put_bool(tracked)
  end

  def summon_portal(npc_object_id, portal_id, start_tick) do
    __MODULE__
    |> build()
    |> put_byte(@summon_portal)
    |> put_int(npc_object_id)
    |> put_int(portal_id)
    |> put_int(start_tick)
  end

  def load_exploration(star_amount) do
    __MODULE__
    |> build()
    |> put_byte(@exploration_progress)
    |> put_int(star_amount)
    |> put_int(0)
  end

  def load_quest_states(quests) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@load_quest_states)
      |> put_int(Enum.count(quests))

    Enum.reduce(quests, packet, fn quest, packet ->
      packet
      |> put_int(quest.quest_id)
      |> put_byte(quest.state)
      |> put_int(quest.completion_count)
      |> put_long(quest.start_time)
      |> put_long(quest.end_time)
      |> put_bool(quest.track)
      |> put_int(map_size(quest.conditions))
      |> reduce(quest.conditions, fn {_index, condition}, packet ->
        put_int(packet, condition.counter)
      end)
    end)
  end

  def load_quests(quest_ids) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@load_quests)
      |> put_int(Enum.count(quest_ids))

    Enum.reduce(quest_ids, packet, fn quest_id, packet ->
      put_int(packet, quest_id)
    end)
  end

  def unknown25 do
    __MODULE__
    |> build()
    |> put_byte(@unknown25)
    |> put_long(0)
  end

  def update_exploration(star_amount) do
    __MODULE__
    |> build()
    |> put_byte(@exploration_reward)
    |> put_int(star_amount)
  end

  def unknown30 do
    __MODULE__
    |> build()
    |> put_byte(@unknown30)
  end

  def load_sky_fortress_missions(quest_ids) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@daily_reputation_missions)
      |> put_bool(true)
      |> put_int(Enum.count(quest_ids))

    Enum.reduce(quest_ids, packet, fn quest_id, packet ->
      put_int(packet, quest_id)
    end)
  end

  def load_kritias_missions(quest_ids) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@weekly_reputation_missions)
      |> put_bool(true)
      |> put_int(Enum.count(quest_ids))

    Enum.reduce(quest_ids, packet, fn quest_id, packet ->
      put_int(packet, quest_id)
    end)
  end

  def alliance_accept(alliance_type) do
    __MODULE__
    |> build()
    |> put_byte(@alliance_accept)
    |> put_byte(alliance_type)
  end

  def alliance_complete(alliance_type) do
    __MODULE__
    |> build()
    |> put_byte(@alliance_complete)
    |> put_byte(alliance_type)
  end

  def unknown38 do
    __MODULE__
    |> build()
    |> put_byte(@unknown38)
  end
end
