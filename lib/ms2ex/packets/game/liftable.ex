defmodule Ms2ex.Packets.Liftable do
  import Ms2ex.Packets.PacketWriter

  @modes %{batch_update: 0x0, update: 0x2, add: 0x3, remove: 0x4}

  @states %{default: 0, removed: 1, disabled: 2, respawning: 3}

  # field-enter batch: the client renders liftable props (and honors their
  # quest masks) from this list; the react flag enables the quest-effect
  # glow — the client lights the prop once the effect quest reaches its
  # wanted state
  def batch_update(liftables) do
    __MODULE__
    |> build()
    |> put_byte(@modes.batch_update)
    |> put_int(length(liftables))
    |> reduce(liftables, fn liftable, packet ->
      packet
      |> put_string(liftable.uuid)
      |> put_byte(1)
      |> put_int(liftable.count)
      |> put_byte(Map.get(@states, liftable.state, 0))
      |> put_ustring(Map.get(liftable, :mask_quest_id, ""))
      |> put_ustring(Map.get(liftable, :mask_quest_state, ""))
      |> put_ustring(Map.get(liftable, :effect_quest_id, ""))
      |> put_ustring(Map.get(liftable, :effect_quest_state, ""))
      |> put_bool(Map.get(liftable, :react_effect, false))
    end)
  end

  def update(liftable) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_string(liftable.uuid)
    |> put_byte(1)
    |> put_int(liftable.count)
    |> put_byte(Map.get(@states, liftable.state, 0))
  end

  # a placed prop joins the field: the client renders it from the cube
  # placement packet; this registration carries its quest masks
  def add(liftable) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_string(liftable.uuid)
    |> put_int(liftable.count)
    |> put_ustring(Map.get(liftable, :mask_quest_id, ""))
    |> put_ustring(Map.get(liftable, :mask_quest_state, ""))
    |> put_ustring(Map.get(liftable, :effect_quest_id, ""))
    |> put_ustring(Map.get(liftable, :effect_quest_state, ""))
    |> put_bool(Map.get(liftable, :react_effect, false))
  end

  # the placed prop was removed (expiry or re-pickup)
  def remove(uuid) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove)
    |> put_string(uuid)
  end
end
