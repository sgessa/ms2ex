defmodule Ms2ex.Packets.AddPortal do
  @behaviour Ms2ex.Packets.Spec

  import Ms2ex.Packets.PacketWriter

  @commands %{add: 0x0, remove: 0x1, update: 0x2}

  def add(portal) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:add])
    |> put_int(portal.id)
    |> put_bool(portal.visible)
    |> put_bool(portal.enable)
    |> put_coord(portal.position)
    |> put_coord(portal.rotation)
    |> put_coord(portal.dimension)
    |> put_ustring()
    |> put_int(portal.target_map_id)
    |> put_int(portal.object_id)
    |> put_int(portal[:action_type] || 0)
    |> put_bool(portal.minimap_visible)
    |> put_long()
    |> put_byte(portal[:type] || 0)
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_bool(false)
    |> put_ustring()
    |> put_ustring()
    |> put_ustring()
  end

  # one-shot portals (quest gates) vanish after use
  def remove(portal_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:remove])
    |> put_int(portal_id)
  end

  # trigger scripts flip portal visibility/enable flags at runtime
  def update(portal) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:update])
    |> put_int(portal.id)
    |> put_bool(portal.visible)
    |> put_bool(portal.enable)
    |> put_bool(portal.minimap_visible)
    |> put_short()
  end

  @impl true
  def commands, do: @commands

  @impl true
  def spec(0x0) do
    [
      id: :int,
      visible: :bool,
      enable: :bool,
      position: :coord,
      rotation: :coord,
      dimension: :coord,
      _model: :ustring,
      target_map_id: :int,
      object_id: :int,
      action_type: :int,
      minimap_visible: :bool,
      _home_id: :long,
      type: :byte,
      _end_tick: :int,
      _unknown: :short,
      _start_tick: :int,
      _has_password: :bool,
      _owner_name: :ustring,
      _reserved_1: :ustring,
      _reserved_2: :ustring
    ]
  end

  def spec(0x1) do
    [id: :int]
  end

  def spec(0x2) do
    [
      id: :int,
      visible: :bool,
      enable: :bool,
      minimap_visible: :bool,
      _unknown: :short
    ]
  end
end
