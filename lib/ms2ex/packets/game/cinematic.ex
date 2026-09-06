defmodule Ms2ex.Packets.Cinematic do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    toggle_ui: 0x1,
    hide: 0x2,
    view: 0x3,
    set_skip: 0x4,
    start_skip: 0x5
  }

  @set_skip_kinds %{
    scene: 0x1,
    state: 0x2
  }

  # cinematic mode toggles the regular ui during scripted sequences
  def toggle_ui(hide) do
    __MODULE__
    |> build()
    |> put_byte(@modes.toggle_ui)
    |> put_bool(hide)
  end

  def hide_ui do
    __MODULE__
    |> build()
    |> put_byte(@modes.hide)
  end

  # shows or hides the client's cutscene skip button; an empty scene hides it
  def set_skip_scene(scene) do
    __MODULE__
    |> build()
    |> put_byte(@modes.set_skip)
    |> put_byte(@set_skip_kinds.scene)
    |> put_string(scene)
  end

  def set_skip_state(state) do
    __MODULE__
    |> build()
    |> put_byte(@modes.set_skip)
    |> put_byte(@set_skip_kinds.state)
    |> put_string(state)
  end

  # confirms the player's skip request so the client tears the cutscene down
  def start_skip do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_skip)
  end

  @aligns %{
    center: 0,
    left: 1,
    right: 2,
    bottom_left: 3,
    bottom_right: 4,
    top_center: 5,
    center_left: 6,
    center_right: 7
  }

  # a speech balloon over an actor's head (the reference's BalloonTalk)
  def balloon_talk(object_id, script, duration) do
    __MODULE__
    |> build()
    |> put_byte(0x8)
    |> put_bool(false)
    |> put_int(object_id)
    |> put_ustring(script)
    |> put_int(duration)
    |> put_int(0)
  end

  # a cinematic dialog bubble during scripted sequences
  def talk(npc_id, illustration, msg, duration, align \\ :left) do
    __MODULE__
    |> build()
    |> put_byte(0x6)
    |> put_int(npc_id)
    |> put_string(illustration)
    |> put_ustring(msg)
    |> put_int(duration)
    |> put_byte(Map.get(@aligns, align, 0))
  end
end
