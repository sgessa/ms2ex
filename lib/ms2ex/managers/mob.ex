defmodule Ms2ex.Mob do
  use GenServer

  alias Ms2ex.{Character, Field, Mobs, Packets}

  defstruct [
    :animation,
    :dead_animation_duration,
    :direction,
    :exp,
    :field,
    :id,
    :last_attacker,
    :model,
    :object_id,
    :position,
    :respawnable?,
    :rotation,
    :spawn_group,
    :speed,
    :stats,
    boss?: false
  ]

  @updates_intval 1_000

  def build(field, npc, spawn_position, spawn_group \\ nil) do
    # TODO get animation sequence from metadata

    respawnable? = if Map.has_key?(npc, :respawnable?), do: npc.respawnable?, else: true

    %__MODULE__{
      animation: npc.animation || 255,
      dead_animation_duration: trunc(npc.dead.time + 3) * 1000,
      direction: npc.rotation.z * 10,
      exp: npc.exp,
      field: Field.field_name(field.field_id, field.channel_id),
      id: npc.id,
      model: npc.model,
      object_id: field.counter,
      position: spawn_position,
      respawnable?: respawnable?,
      rotation: npc.rotation,
      spawn_group: spawn_group,
      stats: npc.stats
    }
  end

  def inflict_dmg(%Character{} = attacker, %__MODULE__{} = mob, dmg) do
    call(mob, {:inflict_dmg, attacker, dmg})
  end

  def lookup(%Character{} = character, object_id) do
    call(character, object_id, :lookup)
  end

  def start(%__MODULE__{} = mob) do
    GenServer.start(__MODULE__, {mob, self()}, name: :"#{mob.field}:mob:#{mob.object_id}")
  end

  def init({mob, field_pid}) do
    Process.monitor(field_pid)

    Field.broadcast(mob.field, Packets.FieldAddNpc.add_mob(mob))
    Field.broadcast(mob.field, Packets.ProxyGameObj.load_npc(mob))

    send(self(), :send_updates)

    {:ok, mob}
  end

  def handle_call(:lookup, _from, mob) do
    {:reply, {:ok, mob}, mob}
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}}, _from, mob) do
    mob = %{mob | last_attacker: attacker}
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
    Field.broadcast(mob.field, Packets.ControlNpc.bytes(:mob, mob))
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, mob}
  end

  def handle_info(:stop, mob) do
    Field.broadcast(mob.field, Packets.FieldRemoveNpc.bytes(mob.object_id))
    Field.broadcast(mob.field, Packets.ProxyGameObj.remove_npc(mob))

    if mob.spawn_group do
      send(mob.field, {:remove_mob, mob.spawn_group.id, mob.object_id})
    end

    if mob.respawnable? do
      respawn_time = mob.spawn_group.data.spawn_time * 1000
      Process.send_after(mob.field, {:add_mob, mob}, respawn_time)
    end

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

  defp kill_mob(mob) do
    Process.send_after(self(), :stop, mob.dead_animation_duration)

    Mobs.drop_rewards(mob)
    Mobs.reward_exp(mob)
    # TODO send achievements
    # TODO check quest
  end

  defp call(%Character{} = char, mob_object_id, msg) do
    process = process_name(char, mob_object_id)

    if pid = Process.whereis(process) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  defp call(%__MODULE__{} = mob, msg) do
    if pid = find_pid(mob) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  defp find_pid(mob) do
    mob
    |> process_name()
    |> Process.whereis()
  end

  defp process_name(%__MODULE__{} = mob) do
    :"#{mob.field}:mob:#{mob.object_id}"
  end

  defp process_name(%Character{} = char, object_id) do
    field_name = Field.field_name(char.field_id, char.channel_id)
    :"#{field_name}:mob:#{object_id}"
  end
end
