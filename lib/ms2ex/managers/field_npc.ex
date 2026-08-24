defmodule Ms2ex.Managers.FieldNpc do
  require Logger
  use GenServer

  alias Ms2ex.{Context, Schema, Packets}
  alias Ms2ex.Types.FieldNpc

  # field update loop ticks every ~15ms
  @updates_intval 15

  # the client asynchronously loads npc entities after FieldAddNpc; controls
  # sent during that window are dropped, so keep broadcasting for a short
  # grace period before falling back to change-driven updates
  @spawn_grace_ms 1000
  @updates_intval 15

  def start(%FieldNpc{} = field_npc) do
    GenServer.start(__MODULE__, {field_npc, self()}, name: process_name(field_npc))
  end

  def init({field_npc, field_pid}) do
    Process.monitor(field_pid)

    Context.Field.broadcast(field_npc.field, Packets.FieldAddNpc.add_npc(field_npc))
    Context.Field.broadcast(field_npc.field, Packets.ProxyGameObj.load_npc(field_npc))

    # send(self(), :test_move)
    send(self(), :send_updates)

    {:ok, field_npc}
  end

  # TODO remove me
  def handle_info(:test_move, %{dead?: false, type: :mob} = field_npc) do
    new_x = Enum.random(-300..300)
    new_y = Enum.random(-300..300)
    new_position = %{field_npc.position | x: new_x, y: new_y}

    Process.send_after(self(), :test_move, :timer.seconds(1))

    {:noreply, %{field_npc | position: new_position, send_control?: true}}
  end

  def handle_info(:test_move, %{dead?: false, type: :npc} = field_npc) do
    new_x = Enum.random(-100..100)
    new_y = Enum.random(-100..100)
    new_position = %{field_npc.position | x: new_x, y: new_y}

    Process.send_after(self(), :test_move, :timer.seconds(1))

    {:noreply, %{field_npc | position: new_position, send_control?: true}}
  end

  def handle_info(:send_updates, %{dead?: true} = field_npc) do
    # death was announced via ControlNpc.dead/1; stay silent until removal
    {:noreply, field_npc}
  end

  # only broadcast when something changed, bumping the sequence counter:
  #   if (send_control && !dead?) { seq_counter++; broadcast(); send_control? = false; }
  def handle_info(:send_updates, field_npc) do
    Process.send_after(self(), :send_updates, @updates_intval)

    if field_npc.dead? do
      {:noreply, field_npc}
    else
      dirty? = field_npc.send_control? or in_spawn_grace?(field_npc)

      if dirty? do
        field_npc = Map.update!(field_npc, :seq_counter, &(&1 + 1))

        Context.Field.broadcast(field_npc.field, Packets.ControlNpc.bytes([field_npc]))
      end

      {:noreply, %{field_npc | send_control?: false}}
    end
  end

  def handle_info(:stop, field_npc) do
    Context.Field.remove_npc(field_npc)

    {:stop, :normal, field_npc}
  end

  # Field Server stopped
  def handle_info({:DOWN, _, _, _pid, _reason}, field_npc) do
    {:stop, :normal, field_npc}
  end

  def handle_info(_, field_npc) do
    {:noreply, field_npc}
  end

  defp in_spawn_grace?(field_npc) do
    System.monotonic_time(:millisecond) - field_npc.born_at < @spawn_grace_ms
  end

  def handle_call(:lookup, _from, field_npc) do
    {:reply, {:ok, field_npc}, field_npc}
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}}, _from, field_npc) do
    field_npc = Map.put(field_npc, :last_attacker, attacker)
    hp = max(0, field_npc.stats.health.current - dmg)
    field_npc = update_stat(field_npc, :health, :current, hp)

    if hp == 0 do
      # Death is announced with ControlNpc.dead/1; the client plays the
      # death animation on its own before the corpse is removed.
      # The hp=0 sync must reach the client BEFORE the dead control entry,
      # otherwise it ignores the state change.
      field_npc = Map.put(field_npc, :dead?, true)

      Logger.debug("NPC #{field_npc.npc.id} died (obj #{field_npc.object_id})")
      Context.Field.broadcast(field_npc.field, Packets.Stats.update_mob_stat(field_npc, :health))
      Context.Field.broadcast(field_npc.field, Packets.ControlNpc.dead(field_npc))

      corpse_time = get_in(field_npc.npc.metadata, [:dead, :time]) || 3
      Process.send_after(self(), :stop, :timer.seconds(corpse_time))

      Context.Mobs.drop_rewards(field_npc)
      Context.Mobs.reward_exp(field_npc)

      # TODO
      # Player Condition update (quest, achievemnts...)

      {:reply, {:ok, field_npc}, field_npc}
    else
      {:reply, {:ok, field_npc}, field_npc}
    end
  end

  # Utils

  defp update_stat(field_npc, stat_id, stat_class, val) do
    stats = put_in(field_npc.stats, [stat_id, stat_class], val)
    Map.put(field_npc, :stats, stats)
  end

  def call(msg, %FieldNpc{} = field_npc) do
    if pid = field_npc |> process_name() |> Process.whereis() do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  def call(msg, character, %FieldNpc{} = field_npc) do
    call(msg, character, field_npc.object_id)
  end

  def call(msg, %Schema.Character{} = character, object_id) do
    process = process_name(character, object_id)

    if pid = Process.whereis(process),
      do: GenServer.call(pid, msg),
      else: :error
  end

  defp process_name(%Schema.Character{} = character, object_id) do
    field_name = Context.Field.field_name(character.map_id, character.channel_id)
    :"#{field_name}:field_npc:#{object_id}"
  end

  defp process_name(%FieldNpc{} = field_npc),
    do: :"#{field_npc.field}:field_npc:#{field_npc.object_id}"
end
