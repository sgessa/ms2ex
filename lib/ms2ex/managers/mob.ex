defmodule Ms2ex.Mob do
  use GenServer

  alias Ms2ex.{Character, Field, Metadata, Packets}

  defstruct [
    :animation,
    :boss?,
    :channel_id,
    :direction,
    :field_id,
    :field_topic,
    :id,
    :object_id,
    :position,
    :rotation,
    :spawn,
    :speed,
    :stats,
    dead?: false
  ]

  @updates_intval 1_000

  def build(field_id, channel_id, object_id, spawn) do
    meta = Metadata.Npcs.get(spawn.mob_id)

    %__MODULE__{
      animation: meta.animation,
      boss?: spawn.boss?,
      channel_id: channel_id,
      direction: meta.rotation.z * 10,
      field_id: field_id,
      field_topic: field_topic(field_id, channel_id),
      id: meta.id,
      object_id: object_id,
      position: spawn.position,
      rotation: meta.rotation,
      spawn: spawn.position,
      stats: meta.stats
    }
  end

  def inflict_dmg(%__MODULE__{} = mob, dmg) do
    call(mob, {:inflict_dmg, dmg})
  end

  def lookup(%Character{} = character, object_id) do
    call(character, object_id, :lookup)
  end

  def start_link(%__MODULE__{} = mob) do
    GenServer.start_link(__MODULE__, mob, name: :"#{mob.field_topic}:mob:#{mob.object_id}")
  end

  def init(mob) do
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
      send(self(), :stop)
      mob = %{mob | dead?: true}
      {:reply, {:ok, mob}, mob}
    else
      {:reply, {:ok, mob}, mob}
    end
  end

  def handle_info(:send_updates, mob) do
    Field.broadcast(mob.field_topic, Packets.ControlNpc.control(:mob, mob))
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, mob}
  end

  defp set_stat(mob, stat_id, stat_val, val) do
    update_in(mob, [Access.key!(:stats), Access.key!(stat_id), Access.key!(stat_val)], fn _ ->
      val
    end)
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

  defp field_topic(field_id, channel_id) do
    field_id
    |> Field.field_name(channel_id)
    |> to_string()
  end

  defp process_name(field_id, channel_id, object_id) do
    :"#{field_topic(field_id, channel_id)}:mob:#{object_id}"
  end
end
