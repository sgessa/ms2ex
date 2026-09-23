defmodule Ms2ex.Managers.CharacterConfig do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "character_configs", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # The character-config manager keeps a character's client config in
  # memory: the hot bar rows (with their quick-slot layout logic), the saved
  # key binds, guide-popup progress, harvest counters and the daily
  # instant-revive allowance. Field enter, quick-slot moves, key-bind syncs,
  # gathering, revivals and skill-build saves read from here instead of
  # querying the database, and every mutation is applied to memory, then
  # persisted through `Ms2ex.Context.CharacterConfigs` and
  # `Ms2ex.Context.HotBars`.

  def start(%Schema.Character{id: id} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # ---- client API ----

  @doc "Lists the character's hot bars, in saved order."
  @spec list(integer()) :: [Schema.HotBar.t()] | :error
  def list(character_id), do: call(character_id, :list)

  @doc "True while no quick slot of any bar holds a skill or item."
  @spec fresh?(integer()) :: boolean() | :error
  def fresh?(character_id), do: call(character_id, :fresh?)

  @doc """
  Moves a quick slot to a target position of the given hot bar and
  persists the bar.
  """
  @spec move_quick_slot(integer(), integer(), Types.QuickSlot.t(), integer()) :: :ok | :error
  def move_quick_slot(character_id, bar_index, quick_slot, target) do
    call(character_id, {:move_quick_slot, bar_index, quick_slot, target})
  end

  @doc """
  Removes the quick slot matching the given skill and item uid from the
  given hot bar and persists the bar.
  """
  @spec remove_quick_slot(integer(), integer(), integer(), integer()) :: :ok | :error
  def remove_quick_slot(character_id, bar_index, skill_id, item_uid) do
    call(character_id, {:remove_quick_slot, bar_index, skill_id, item_uid})
  end

  @doc """
  Activates the hot bar at the given index (the client's active-bar switch)
  and persists the flag flip.
  """
  @spec set_active_bar(integer(), integer()) :: :ok | :error
  def set_active_bar(character_id, bar_index) do
    call(character_id, {:set_active_bar, bar_index})
  end

  @doc """
  Syncs the bars with the character's learned active skills: pure-skill
  slots whose skill is no longer learned are cleared from every bar, and
  learned actives missing from the active bar are placed in the next free
  slot. Changed bars are persisted.
  """
  @spec update_hotbar_skills(Schema.Character.t()) :: :ok | :error
  def update_hotbar_skills(%Schema.Character{id: id} = character) do
    call(id, {:update_hotbar_skills, learned_active_skill_ids(character)})
  end

  @doc "Returns the character's saved key binds, keyed by key code."
  @spec key_binds(integer()) :: map() | :error
  def key_binds(character_id), do: call(character_id, :key_binds)

  @doc """
  Merges client-sent key binds into the saved table (each entry upserted by
  key code) and persists the row.
  """
  @spec merge_key_binds(integer(), map()) :: :ok | :error
  def merge_key_binds(character_id, binds), do: call(character_id, {:merge_key_binds, binds})

  @doc "Returns the character's guide-popup progress, keyed by guide id."
  @spec guide_records(integer()) :: map() | :error
  def guide_records(character_id), do: call(character_id, :guide_records)

  @doc """
  Merges client-reported guide steps into the saved progress and persists
  the row.
  """
  @spec merge_guide_records(integer(), map()) :: :ok | :error
  def merge_guide_records(character_id, records),
    do: call(character_id, {:merge_guide_records, records})

  @doc "Returns the character's harvest counts, keyed by recipe id."
  @spec gathering_counts(integer()) :: map() | :error
  def gathering_counts(character_id), do: call(character_id, :gathering_counts)

  @doc "Bumps the harvest counter of a gathering recipe and persists it."
  @spec bump_gathering_count(integer(), integer()) :: :ok | :error
  def bump_gathering_count(character_id, recipe_id),
    do: call(character_id, {:bump_gathering_count, recipe_id})

  @doc "Returns how many daily instant revives were used."
  @spec instant_revive_count(integer()) :: integer()
  def instant_revive_count(character_id) do
    case call(character_id, :instant_revive_count) do
      count when is_integer(count) ->
        count

      # no live manager (e.g. damage racing the session teardown): read the row
      :error ->
        Context.CharacterConfigs.get(character_id).instant_revive_count
    end
  end

  @doc "Counts one instant revive against the daily allowance and persists it."
  @spec bump_instant_revive_count(integer()) :: :ok | :error
  def bump_instant_revive_count(character_id), do: call(character_id, {:bump_instant_revive_count})

  @doc """
  Drops the cached daily state (harvest counts, instant-revive allowance)
  after the daily reset bulk-cleared it in the database.
  """
  @spec reset_daily(integer()) :: :ok
  def reset_daily(character_id), do: cast(character_id, :reset_daily)

  # prunes unlearned pure-skill slots from every bar and fills the active
  # bar's free slots with the learned skills; returns the updated bars and
  # the subset that differs from the input, for persistence
  defp apply_learned_skills(hot_bars, skill_ids) do
    active_index = Enum.find_index(hot_bars, & &1.active) || 0

    old_new =
      Enum.map(Enum.with_index(hot_bars), fn {hot_bar, index} ->
        updated =
          if index == active_index do
            Enum.reduce(skill_ids, hot_bar, &assign_free_skill(&2, &1))
          else
            hot_bar
          end

        {hot_bar, prune_unlearned_skills(updated, skill_ids)}
      end)

    updated = Enum.map(old_new, fn {_old, new} -> new end)
    changed_pairs = Enum.filter(old_new, fn {old, new} -> old != new end)

    {updated, changed_pairs}
  end

  # flips the active flag onto the bar at the given index; an out-of-range
  # index leaves the bars unchanged
  defp activate_bar(hot_bars, bar_index) when bar_index in 0..(length(hot_bars) - 1)//1 do
    old_new =
      Enum.map(Enum.with_index(hot_bars), fn {hot_bar, index} ->
        {hot_bar, %{hot_bar | active: index == bar_index}}
      end)

    updated = Enum.map(old_new, fn {_old, new} -> new end)
    changed_pairs = Enum.filter(old_new, fn {old, new} -> old != new end)

    {updated, changed_pairs}
  end

  defp activate_bar(hot_bars, _bar_index), do: {hot_bars, []}

  # ---- server callbacks ----

  @impl true
  def init(character) do
    config = Context.CharacterConfigs.get(character.id)

    {:ok,
     %{
       character_id: character.id,
       hot_bars: Context.HotBars.list(character),
       config: config
     }}
  end

  @impl true
  def handle_call(:list, _from, state), do: {:reply, state.hot_bars, state}

  @impl true
  def handle_call(:fresh?, _from, state),
    do: {:reply, Enum.all?(state.hot_bars, &empty_bar?/1), state}

  @impl true
  def handle_call({:move_quick_slot, bar_index, quick_slot, target}, _from, state) do
    with %Schema.HotBar{} = hot_bar <- Enum.at(state.hot_bars, bar_index),
         {:ok, updated} <- move_quick_slot(hot_bar, quick_slot, target),
         {:ok, persisted} <- Context.HotBars.update_quick_slots(hot_bar, updated.quick_slots) do
      {:reply, :ok, %{state | hot_bars: replace_bar(state.hot_bars, persisted)}}
    else
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:remove_quick_slot, bar_index, skill_id, item_uid}, _from, state) do
    with %Schema.HotBar{} = hot_bar <- Enum.at(state.hot_bars, bar_index),
         {:ok, updated} <- remove_quick_slot(hot_bar, skill_id, item_uid),
         {:ok, persisted} <- Context.HotBars.update_quick_slots(hot_bar, updated.quick_slots) do
      {:reply, :ok, %{state | hot_bars: replace_bar(state.hot_bars, persisted)}}
    else
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:set_active_bar, bar_index}, _from, state) do
    {_updated_bars, changed_pairs} = activate_bar(state.hot_bars, bar_index)

    state =
      Enum.reduce(changed_pairs, state, fn {hot_bar, updated}, state ->
        {:ok, persisted} = Context.HotBars.set_active(hot_bar, updated.active)
        %{state | hot_bars: replace_bar(state.hot_bars, persisted)}
      end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_hotbar_skills, skill_ids}, _from, state) do
    {_updated_bars, changed_pairs} = apply_learned_skills(state.hot_bars, skill_ids)

    state =
      Enum.reduce(changed_pairs, state, fn {hot_bar, updated}, state ->
        {:ok, persisted} = Context.HotBars.update_quick_slots(hot_bar, updated.quick_slots)
        %{state | hot_bars: replace_bar(state.hot_bars, persisted)}
      end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:key_binds, _from, state), do: {:reply, state.config.key_binds, state}

  @impl true
  def handle_call({:merge_key_binds, binds}, _from, state) do
    key_binds = Map.merge(state.config.key_binds, binds)

    case Context.CharacterConfigs.update_field(state.config, :key_binds, key_binds) do
      {:ok, config} -> {:reply, :ok, %{state | config: config}}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call(:guide_records, _from, state), do: {:reply, state.config.guide_records, state}

  @impl true
  def handle_call({:merge_guide_records, records}, _from, state) do
    guide_records = Map.merge(state.config.guide_records, records)

    case Context.CharacterConfigs.update_field(state.config, :guide_records, guide_records) do
      {:ok, config} -> {:reply, :ok, %{state | config: config}}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call(:gathering_counts, _from, state),
    do: {:reply, state.config.gathering_counts, state}

  @impl true
  def handle_call({:bump_gathering_count, recipe_id}, _from, state) do
    counts = Map.update(state.config.gathering_counts, recipe_id, 1, &(&1 + 1))

    case Context.CharacterConfigs.update_field(state.config, :gathering_counts, counts) do
      {:ok, config} -> {:reply, :ok, %{state | config: config}}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call(:instant_revive_count, _from, state),
    do: {:reply, state.config.instant_revive_count, state}

  @impl true
  def handle_call({:bump_instant_revive_count}, _from, state) do
    count = state.config.instant_revive_count + 1

    case Context.CharacterConfigs.update_field(state.config, :instant_revive_count, count) do
      {:ok, config} -> {:reply, :ok, %{state | config: config}}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast(:reset_daily, state) do
    config = %{state.config | gathering_counts: %{}, instant_revive_count: 0}
    {:noreply, %{state | config: config}}
  end

  defp replace_bar(hot_bars, updated_bar) do
    Enum.map(hot_bars, fn bar ->
      if bar.id == updated_bar.id, do: updated_bar, else: bar
    end)
  end

  # ---- quick-slot layout ----

  # slots past the assignable range hold the client's page controls
  @assignable_slots 22

  # fixed placement order when a skill lands on the first free slot
  @slot_order [4, 5, 6, 7, 0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]

  # True when no slot of the bar holds a skill or item.
  defp empty_bar?(%Schema.HotBar{quick_slots: slots}) do
    Enum.all?(slots, &empty_slot?/1)
  end

  # Places a quick slot at the target position, swapping with the slot it
  # already occupies when present. A target outside the assignable range
  # falls back to the first free slot, replacing slot 0 when the bar is full.
  defp move_quick_slot(%Schema.HotBar{quick_slots: slots} = hot_bar, quick_slot, target) do
    target = resolve_target(slots, target)
    slots = swap_source(slots, quick_slot, target)

    {:ok, %{hot_bar | quick_slots: put_slot(slots, target, quick_slot)}}
  end

  # Replaces the quick slot matching the given skill and item uid with an
  # empty slot.
  defp remove_quick_slot(%Schema.HotBar{quick_slots: slots} = hot_bar, skill_id, item_uid) do
    case find_slot_index(slots, skill_id, item_uid) do
      nil ->
        :error

      index ->
        slots = List.update_at(slots, index, fn _ -> %Types.QuickSlot{} end)
        {:ok, %{hot_bar | quick_slots: slots}}
    end
  end

  # Clears pure-skill slots (no bound item) whose skill is not in the learned
  # set: bound item slots survive so emotes and items keep their places.
  defp prune_unlearned_skills(%Schema.HotBar{quick_slots: slots} = hot_bar, learned_ids) do
    slots =
      Enum.map(slots, fn
        %Types.QuickSlot{skill_id: skill_id, item_uid: 0} = slot when skill_id > 0 ->
          if skill_id in learned_ids do
            slot
          else
            %Types.QuickSlot{}
          end

        slot ->
          slot
      end)

    %{hot_bar | quick_slots: slots}
  end

  # Assigns a skill to the first free slot when the bar does not hold it yet;
  # a full bar is left unchanged.
  defp assign_free_skill(%Schema.HotBar{quick_slots: slots} = hot_bar, skill_id) do
    assigned? = Enum.any?(slots, &match?(%Types.QuickSlot{skill_id: ^skill_id, item_uid: 0}, &1))

    case {assigned?, free_slot_index(slots)} do
      {true, _index} ->
        hot_bar

      {_assigned, nil} ->
        hot_bar

      {false, index} ->
        %{hot_bar | quick_slots: put_slot(slots, index, %Types.QuickSlot{skill_id: skill_id})}
    end
  end

  # the target is taken as-is inside the assignable range; outside it the
  # quick slot lands on the first free slot, replacing slot 0 when none is
  # free
  defp resolve_target(_slots, target) when target in 0..(@assignable_slots - 1)//1, do: target

  defp resolve_target(slots, _target), do: free_slot_index(slots) || 0

  # a move whose quick slot already sits on the bar swaps the two positions:
  # the target's old content moves to the source position
  defp swap_source(slots, quick_slot, target) do
    case find_slot_index(slots, quick_slot.skill_id, quick_slot.item_uid) do
      nil -> slots
      source_index -> List.update_at(slots, source_index, fn _ -> Enum.at(slots, target) end)
    end
  end

  defp put_slot(slots, target, quick_slot) do
    List.update_at(slots, target, fn _ -> quick_slot end)
  end

  defp find_slot_index(slots, skill_id, item_uid) do
    Enum.find_index(slots, &(&1.skill_id == skill_id and &1.item_uid == item_uid))
  end

  defp free_slot_index(slots) do
    Enum.find(@slot_order, fn index ->
      slots |> Enum.at(index) |> empty_slot?()
    end)
  end

  defp empty_slot?(%Types.QuickSlot{skill_id: 0, item_id: 0, item_uid: 0}), do: true
  defp empty_slot?(_slot), do: false

  # learned in-battle skills of the active skill tab, above the 10M id range
  defp learned_active_skill_ids(%Schema.Character{
         skill_tabs: tabs,
         active_skill_tab_id: active_id
       })
       when is_list(tabs) do
    case Enum.find(tabs, &(&1.id == active_id)) do
      %Schema.SkillTab{skills: skills} when is_list(skills) ->
        skills
        |> Enum.filter(&learned_active_skill?/1)
        |> Enum.map(& &1.skill_id)
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp learned_active_skill_ids(_character), do: []

  defp learned_active_skill?(skill) do
    skill.level > 0 and skill.skill_id > 10_000_000 and skill_in_battle?(skill.skill_id)
  end

  defp skill_in_battle?(skill_id) do
    case Storage.Skills.get_meta(skill_id) do
      %{state: %{in_battle: in_battle}} -> in_battle
      _ -> false
    end
  end
end
