defmodule Ms2ex.Managers.FieldNpc do
  use GenServer

  alias Ms2ex.{Field, Schema, Packets, Context}
  alias Ms2ex.Types.FieldNpc

  @updates_intval 1_000

  def start(%FieldNpc{} = field_npc) do
    GenServer.start(__MODULE__, {field_npc, self()}, name: process_name(field_npc))
  end

  def init({field_npc, field_pid}) do
    Process.monitor(field_pid)

    Field.broadcast(field_npc.field, Packets.FieldAddNpc.add_npc(field_npc))
    Field.broadcast(field_npc.field, Packets.ProxyGameObj.load_npc(field_npc))

    send(self(), :send_updates)

    {:ok, field_npc}
  end

  def handle_info(:send_updates, field_npc) do
    Field.broadcast(field_npc.field, Packets.ControlNpc.bytes(field_npc))
    Field.broadcast(field_npc.field, Packets.ProxyGameObj.update_npc(field_npc))

    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, field_npc}
  end

  def handle_info(:stop, field_npc) do
    Field.broadcast(field_npc.field, Packets.FieldRemoveNpc.bytes(field_npc.object_id))
    Field.broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

    # TODO
    # We should tell FieldServer

    {:stop, :normal, field_npc}
  end

  # Field Server stopped
  def handle_info({:DOWN, _, _, _pid, _reason}, field_npc) do
    {:stop, :normal, field_npc}
  end

  def handle_call(:lookup, _from, field_npc) do
    {:reply, {:ok, field_npc}, field_npc}
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}}, _from, field_npc) do
    # TODO
    # Ensure can be hitted (field_npc.type == :mob)

    field_npc = Map.put(field_npc, :last_attacker, attacker)
    hp = max(0, field_npc.stats.health - dmg)
    field_npc = update_stat(field_npc, :hp, hp)

    if hp == 0 do
      # TODO
      # Death animation
      field_npc = Map.put(field_npc, :dead?, true)
      Process.send_after(self(), :stop, :timer.seconds(field_npc.npc.metadata.dead.time))

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

  defp update_stat(field_npc, stat_id, val) do
    stats = Map.put(field_npc.stats, stat_id, val)
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
    field_name = Field.field_name(character.map_id, character.channel_id)
    :"#{field_name}:field_npc:#{object_id}"
  end

  defp process_name(%FieldNpc{} = field_npc),
    do: :"#{field_npc.field}:field_npc:#{field_npc.object_id}"
end
