defmodule Ms2ex.Managers.Character do
  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Context.StatPoints
  alias Ms2ex.Constants
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Managers.Character
  alias Ms2ex.Types.AttributePointSource

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @spec lookup(integer()) :: {:ok, Schema.Character.t()} | :error
  def lookup(character_id), do: call(character_id, :lookup)

  # TODO avoid SQL
  @spec lookup_by_name(String.t()) :: {:ok, Schema.Character.t()} | :error
  def lookup_by_name(character_name) do
    case Context.Characters.get_by(name: character_name) do
      nil -> :error
      %Schema.Character{id: char_id} -> lookup(char_id)
    end
  end

  @spec update(Schema.Character.t()) :: :ok | :error
  def update(%Schema.Character{} = character), do: call(character, {:update, character})

  @spec set_level(Schema.Character.t(), integer()) :: {:ok, Schema.Character.t()} | :error
  def set_level(%Schema.Character{} = character, level) do
    call(character, {:set_level, level})
  end

  @spec save_skill_cooldown(Schema.Character.t(), map()) :: :ok | :error
  def save_skill_cooldown(%Schema.Character{} = character, cooldown) do
    call(character, {:save_skill_cooldown, cooldown})
  end

  @spec set_skill_cooldown(Schema.Character.t(), integer(), integer(), integer()) ::
          {:ok, map()} | :error
  def set_skill_cooldown(%Schema.Character{} = character, skill_id, level, end_tick) do
    call(character, {:set_skill_cooldown, skill_id, level, end_tick})
  end

  @spec get_skill_cooldowns(integer()) :: {:ok, [map()]} | :error
  def get_skill_cooldowns(character_id) do
    call(character_id, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
  end

  @spec add_stat_point(Schema.Character.t(), AttributePointSource.t(), pos_integer()) ::
          {:ok, Schema.Character.t()} | :error
  def add_stat_point(%Schema.Character{} = character, source, amount) when amount > 0 do
    call(character, {:add_stat_point, source, amount})
  end

  @spec allocate_stat_point(Schema.Character.t(), atom() | integer()) ::
          {:ok, Schema.Character.t()} | :error
  def allocate_stat_point(%Schema.Character{} = character, attribute) do
    call(character, {:allocate_stat_point, attribute})
  end

  @spec reset_stat_points(Schema.Character.t()) :: {:ok, Schema.Character.t()} | :error
  def reset_stat_points(%Schema.Character{} = character) do
    call(character, :reset_stat_points)
  end

  def monitor(%Schema.Character{} = character), do: call(character, :monitor)

  def call(%Schema.Character{id: id}, msg) do
    if pid = Process.whereis(process_name(id)) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  def call(character_id, msg) do
    if pid = Process.whereis(process_name(character_id)) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  def cast(%Schema.Character{id: id}, msg), do: GenServer.cast(process_name(id), msg)
  def cast(character_id, msg), do: GenServer.cast(process_name(character_id), msg)

  def start(%Schema.Character{} = character) do
    GenServer.start(__MODULE__, character, name: process_name(character.id))
  end

  def init(character) do
    {:ok,
     character
     |> Map.put(:regen_hp?, false)
     |> Map.put(:regen_sp?, false)
     |> Map.put(:regen_sta?, false)
     |> Map.put(:skill_cooldowns, %{})
     |> Map.update(
       :stat_point_sources,
       AttributePointSource.default_sources(),
       &AttributePointSource.normalize/1
     )
     |> Map.update(:stat_point_allocation, %{}, &StatPoints.normalize_allocation/1)}
  end

  def handle_call(:lookup, _from, character) do
    {:reply, {:ok, character}, character}
  end

  def handle_call({:update, character}, _from, state) do
    {:reply, :ok,
     character
     |> Map.put(:skill_cooldowns, Map.get(state, :skill_cooldowns, %{}))
     |> Map.put(:stat_point_sources, state.stat_point_sources)
     |> Map.put(:stat_point_allocation, state.stat_point_allocation)}
  end

  def handle_call({:set_level, level}, _from, character) do
    level = level |> max(1) |> min(Constants.get(:character_max_level))
    old_level = character.level
    {:ok, character} = Context.Characters.update(character, %{exp: 0, level: level})
    character = refresh_level(character, old_level)

    {:reply, {:ok, character}, character}
  end

  def handle_call(:monitor, {pid, _}, character) do
    Process.monitor(pid)
    {:reply, :ok, character}
  end

  # --------------------------------
  # Stat Points (AP)
  # --------------------------------

  def handle_call({:add_stat_point, source, amount}, _from, character) do
    source = if is_atom(source), do: source, else: AttributePointSource.get_key(source)

    if source in AttributePointSource.all() do
      sources = Map.update(character.stat_point_sources, source, amount, &(&1 + amount))

      case Context.Characters.update_stat_points(
             character,
             sources,
             character.stat_point_allocation
           ) do
        {:ok, _} ->
          character = %{character | stat_point_sources: sources}
          # sources packet triggers the "Received AP" in-game notification
          push(character, Packets.StatPoints.sources(sources))
          {:reply, {:ok, character}, character}

        {:error, _} ->
          {:reply, :error, character}
      end
    else
      {:reply, :error, character}
    end
  end

  def handle_call({:allocate_stat_point, attribute}, _from, character) do
    with {:ok, stat} <- StatPoints.attribute(attribute) do
      total = character.stat_point_sources |> Map.values() |> Enum.sum()
      used = character.stat_point_allocation |> Map.values() |> Enum.sum()
      limit = Application.get_env(:ms2ex, :constants)[:stat_point_limits] |> Map.get(stat, 100)
      current = Map.get(character.stat_point_allocation, stat, 0)

      cond do
        used >= total ->
          # no points available — silent failure
          {:reply, :error, character}

        current >= limit ->
          push(character, Packets.Notice.message("s_char_info_limit_stat_point"))
          {:reply, :error, character}

        true ->
          allocation = Map.put(character.stat_point_allocation, stat, current + 1)

          case Context.Characters.update_stat_points(
                 character,
                 character.stat_point_sources,
                 allocation
               ) do
            {:ok, _} ->
              character = StatPoints.apply_attribute(character, stat, 1)
              character = %{character | stat_point_allocation: allocation}
              Context.Field.broadcast(character, Packets.Stats.update_char_stats(character, stat))
              push(character, Packets.StatPoints.allocation(allocation, total))
              {:reply, {:ok, character}, character}

            {:error, _} ->
              {:reply, :error, character}
          end
      end
    else
      _ -> {:reply, :error, character}
    end
  end

  def handle_call(:reset_stat_points, _from, character) do
    total = character.stat_point_sources |> Map.values() |> Enum.sum()

    case Context.Characters.update_stat_points(character, character.stat_point_sources, %{}) do
      {:ok, _} ->
        # revert each allocated attribute and notify client
        character =
          Enum.reduce(character.stat_point_allocation, character, fn {stat, amount}, char ->
            char = StatPoints.apply_attribute(char, stat, -amount)
            Context.Field.broadcast(char, Packets.Stats.update_char_stats(char, stat))
            char
          end)

        character = %{character | stat_point_allocation: %{}}
        push(character, Packets.StatPoints.allocation(%{}, total))
        push(character, Packets.Notice.message("s_char_info_reset_stat_pointsuccess_msg"))
        {:reply, {:ok, character}, character}

      {:error, _} ->
        {:reply, :error, character}
    end
  end

  # --------------------------------
  # Skills
  # --------------------------------

  def handle_call({:cast_skill, skill_cast}, _from, character) do
    character = Character.Skill.cast_skill(character, skill_cast)
    {:reply, {:ok, character}, character}
  end

  def handle_call({:save_skill_cooldown, cooldown}, _from, character) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    existing = Map.get(cooldowns, cooldown.skill_id)

    cooldown =
      if is_nil(existing) or cooldown.start_tick > existing.end_tick do
        %{
          skill_id: cooldown.skill_id,
          level: cooldown.level,
          group_id: cooldown.group_id,
          end_tick: cooldown.end_tick,
          recharge_max_count: cooldown.recharge_max_count,
          charges: 0
        }
      else
        existing
      end

    cooldown =
      if cooldown.recharge_max_count > 0 do
        %{cooldown | charges: min(cooldown.charges + 1, cooldown.recharge_max_count)}
      else
        cooldown
      end

    character =
      Map.put(character, :skill_cooldowns, Map.put(cooldowns, cooldown.skill_id, cooldown))

    {:reply, :ok, character}
  end

  def handle_call({:set_skill_cooldown, skill_id, level, end_tick}, _from, character) do
    cooldown = %{
      skill_id: skill_id,
      level: level,
      group_id: 0,
      end_tick: end_tick,
      recharge_max_count: 0,
      charges: 0
    }

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.put(Map.get(character, :skill_cooldowns, %{}), skill_id, cooldown)
      )

    {:reply, {:ok, cooldown}, character}
  end

  def handle_call({:get_skill_cooldowns, now}, _from, character) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    active = Map.values(cooldowns) |> Enum.filter(&(&1.end_tick > now))

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.filter(cooldowns, fn {_id, cooldown} -> cooldown.end_tick > now end)
      )

    {:reply, {:ok, active}, character}
  end

  # --------------------------------
  # Stats
  # --------------------------------

  def handle_cast({:consume_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.decrease(character, stat_id, amount)}
  end

  def handle_cast({:set_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.set(character, stat_id, amount)}
  end

  def handle_cast({:modify_buff_status, modifiers}, character) do
    character =
      Enum.reduce(modifiers, character, fn {stat, amount}, character ->
        Character.Stats.modify_max(character, stat, amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:remove_buff_status, modifiers}, character) do
    character =
      Enum.reduce(modifiers, character, fn {stat, amount}, character ->
        Character.Stats.modify_max(character, stat, -amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:increase_stats, stats}, character) do
    character =
      Enum.reduce(stats, character, fn {stat, amount}, character ->
        Character.Stats.increase(character, stat, amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:decrease_stats, stats}, character) do
    character =
      Enum.reduce(stats, character, fn {stat, amount}, character ->
        Character.Stats.decrease(character, stat, amount)
      end)

    {:noreply, character}
  end

  # --------------------------------
  # Exp
  # --------------------------------

  def handle_cast({:earn_exp, amount}, character) do
    old_lvl = character.level
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    {:ok, character} = Context.Experience.maybe_add_exp(character, amount)
    character = refresh_level(character, old_lvl)

    push(character, Packets.Experience.bytes(amount, character.exp, character.rest_exp))

    {:noreply, Map.put(character, :skill_cooldowns, cooldowns)}
  end

  def handle_cast({:receive_fall_dmg, distance}, character) do
    hp = Map.get(character.stats, :health_cur)
    dmg = Context.Damage.calculate_fall_dmg(character, distance)
    character = Character.Stats.set(character, :health, hp - dmg)

    push(character, Packets.FallDamage.bytes(character, dmg))

    {:noreply, character}
  end

  def handle_info({:regen, stat_id}, character) do
    {:noreply, Character.Stats.regen(character, stat_id)}
  end

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

  defp refresh_level(character, old_level) do
    if old_level != character.level do
      {character, _equipment_stats} = Context.CharacterStats.apply(character)
      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
      Context.Field.broadcast_stats(character)
      character
    else
      character
    end
  end

  defp process_name(character_id),
    do: :"characters:#{character_id}"
end
