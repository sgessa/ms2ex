defmodule Ms2ex.Packets.ProxyGameObj do
  alias Ms2ex.Schema
  alias Ms2ex.Packets
  alias Ms2ex.Enums

  import Packets.PacketWriter

  @modes %{
    load_player: 0x3,
    remove_player: 0x4,
    update_player: 0x5,
    load_npc: 0x6,
    remove_npc: 0x7,
    update_npc: 0x8
  }

  # which fields follow the flag byte
  @player_flags %{
    dead: 0x01,
    position: 0x02,
    level: 0x04,
    job: 0x08,
    motto: 0x10,
    gear_score: 0x20,
    state: 0x40
  }

  def load_player(character) do
    real_job_id = Enums.Job.get_value(character.job)

    __MODULE__
    |> build()
    |> put_byte(@modes.load_player)
    |> put_int(character.object_id)
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_ustring(character.profile_url)
    |> put_ustring(character.motto)
    |> put_byte()
    |> put_coord(character.position)
    |> put_short(character.level)
    |> put_short(real_job_id)
    |> put_int(Schema.Character.job_id(character))
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_ustring(character.home_name)
    |> put_int()
    |> put_short()
    |> reduce(character.trophies, fn trophy, packet -> put_int(packet, trophy) end)
  end

  # periodic position sync for other clients
  def update_player(character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update_player)
    |> put_int(character.object_id)
    |> put_byte(@player_flags.position)
    |> put_coord(character.position)
  end

  # actor state transitions (idle, casting, etc.) reach clients through the
  # state flag; values mirror the client's actor state enum (idle=1,
  # pc_skill=16)
  def update_state(character, state) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update_player)
    |> put_int(character.object_id)
    |> put_byte(@player_flags.state)
    |> put_short(state)
  end

  def remove_player(object_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove_player)
    |> put_int(object_id)
  end

  def load_npc(field_npc) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_npc)
    |> put_int(field_npc.object_id)
    |> put_int(field_npc.npc.id)
    |> put_bool(field_npc.dead?)
    |> put_int(field_npc.spawn_point_id)
    |> put_coord(field_npc.position)
  end

  def remove_npc(field_npc) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove_npc)
    |> put_int(field_npc.object_id)
  end

  def update_npc(field_npc) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update_npc)
    |> put_int(field_npc.object_id)
    |> put_bool(field_npc.dead?)
    |> put_coord(field_npc.position)
  end
end
