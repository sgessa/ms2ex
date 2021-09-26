defmodule Ms2ex.Mob do
  use GenServer

  alias Ms2ex.{Character, Field, Packets}

  defstruct [
    :animation,
    :channel_id,
    :dead_animation_duration,
    :direction,
    :field_id,
    :field_topic,
    :id,
    :model,
    :object_id,
    :position,
    :rotation,
    :speed,
    :stats,
    boss?: false,
    dead?: false,
    respawn?: true
  ]

  @updates_intval 1_000

  def build(field, npc, spawn_position) do
    # TODO get animation sequence from metadata

    %__MODULE__{
      animation: npc.animation || 255,
      channel_id: field.channel_id,
      dead_animation_duration: trunc(npc.dead.time + 3) * 1000,
      direction: npc.rotation.z * 10,
      field_id: field.field_id,
      field_topic: Field.field_topic(field.field_id, field.channel_id),
      id: npc.id,
      model: npc.model,
      object_id: field.counter,
      position: spawn_position,
      rotation: npc.rotation,
      stats: npc.stats
    }
  end

  def inflict_dmg(%__MODULE__{} = mob, dmg) do
    call(mob, {:inflict_dmg, dmg})
  end

  def lookup(%Character{} = character, object_id) do
    call(character, object_id, :lookup)
  end

  def start(%__MODULE__{} = mob) do
    GenServer.start(__MODULE__, {mob, self()}, name: :"#{mob.field_topic}:mob:#{mob.object_id}")
  end

  def init({mob, field_pid}) do
    Process.monitor(field_pid)

    Field.broadcast(mob.field_topic, Packets.FieldAddNpc.add_mob(mob))
    Field.broadcast(mob.field_topic, Packets.ProxyGameObj.load_npc(mob))

    send(self(), :send_updates)

    {:ok, mob}
  end

  def handle_call(:lookup, _from, mob) do
    {:reply, {:ok, mob}, mob}
  end

  def handle_call({:inflict_dmg, %{dmg: dmg}}, _from, mob) do
    hp = max(0, mob.stats.hp.total - dmg)
    mob = set_stat(mob, :hp, :total, hp)

    if hp == 0 do
      kill_mob(mob)
      {:reply, {:ok, mob}, mob}
    else
      {:reply, {:ok, mob}, mob}
    end
  end

  def handle_info(:send_updates, mob) do
    Field.broadcast(mob.field_topic, Packets.FieldObject.control(:mob, mob))
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, mob}
  end

  def handle_info(:stop, mob) do
    Field.broadcast(mob.field_topic, Packets.FieldRemoveNpc.bytes(mob.object_id))
    Field.broadcast(mob.field_topic, Packets.FieldObject.remove_npc(mob))
    {:stop, :normal, mob}
  end

  # Field Server stopped
  def handle_info({:DOWN, _, _, _pid, _reason}, mob) do
    {:stop, :normal, mob}
  end

  defp set_stat(mob, stat_id, stat_val, val) do
    update_in(mob, [Access.key!(:stats), Access.key!(stat_id), Access.key!(stat_val)], fn _ ->
      val
    end)
  end

  # @respawn_intval 10_000
  defp kill_mob(mob) do
    # Mobs.process_death(character, target)
    Process.send_after(self(), :stop, mob.dead_animation_duration)
    #  if target.respawn,
    #    do: Process.send_after(self(), {:respawn_mob, target}, @respawn_intval)
    %{mob | dead?: true}
  end

  defp call(char, mob_object_id, msg) do
    process = process_name(char.field_id, char.channel_id, mob_object_id)

    if pid = Process.whereis(process) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  defp call(mob, msg) do
    if pid = find_pid(mob) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  defp find_pid(char_or_mob) do
    char_or_mob.field_id
    |> process_name(char_or_mob.channel_id, char_or_mob.object_id)
    |> Process.whereis()
  end

  defp process_name(field_id, channel_id, object_id) do
    field_name = Field.field_name(field_id, channel_id)
    :"#{field_name}:mob:#{object_id}"
  end
end
