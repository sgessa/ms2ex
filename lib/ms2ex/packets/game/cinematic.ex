defmodule Ms2ex.Packets.Cinematic do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    toggle_ui: 0x1,
    hide: 0x2,
    view: 0x3,
    set_skip: 0x4,
    start_skip: 0x5,
    talk: 0x6,
    remove_talk: 0x7,
    balloon_talk: 0x8,
    caption: 0xA,
    opening: 0xB
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

  # frames a cutscene: letterbox bars (3), fade (4), horizontal (5) or
  # vertical (6) wipes — the transition id is carried verbatim; the script
  # text overlays the transition
  def view(transition, script) do
    __MODULE__
    |> build()
    |> put_byte(@modes.view)
    |> put_int(transition)
    |> put_ustring(script)
    |> put_ustring("")
  end

  # black screen with text (scripted intros); the bool flags an unknown
  # client variant
  def opening(script, unknown \\ false) do
    __MODULE__
    |> build()
    |> put_byte(@modes.opening)
    |> put_ustring(script)
    |> put_bool(unknown)
  end

  # a screen-space caption banner (type NameCaption renders the named-title
  # card at the end of scripted beats); align carries the client's
  # camel-case enum name verbatim. NameCaption entries zero both offset
  # rates together when only one is set
  def caption(type, title, script, align, duration, offset_rate_x, offset_rate_y, scale) do
    {offset_rate_x, offset_rate_y} =
      if type == "NameCaption" and (offset_rate_x == 0.0 or offset_rate_y == 0.0) do
        {0.0, 0.0}
      else
        {offset_rate_x, offset_rate_y}
      end

    __MODULE__
    |> build()
    |> put_byte(@modes.caption)
    |> put_ustring(type)
    |> put_ustring(title)
    |> put_ustring(script)
    |> put_ustring(align)
    |> put_int(duration)
    |> put_float(offset_rate_x)
    |> put_float(offset_rate_y)
    |> put_float(scale)
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

  # a speech balloon over an actor's head. The npc flag stays unset: the
  # client only renders unflagged balloons (a flagged npc balloon is sent
  # and never appears; the reference's own set_dialogue also flags npc
  # balloons false)
  def balloon_talk(object_id, script, duration, delay \\ 0) do
    __MODULE__
    |> build()
    |> put_byte(0x8)
    |> put_bool(false)
    |> put_int(object_id)
    |> put_ustring(script)
    |> put_int(duration)
    |> put_int(delay)
  end

  # a cinematic dialog bubble during scripted sequences
  def talk(npc_id, illustration, msg, duration, align \\ :left) do
    __MODULE__
    |> build()
    |> put_byte(@modes.talk)
    |> put_int(npc_id)
    |> put_string(illustration)
    |> put_ustring(msg)
    |> put_int(duration)
    |> put_byte(Map.get(@aligns, align, 0))
  end

  # clears the cinematic dialog bubble at the end of a scripted talk beat
  def remove_talk do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove_talk)
  end
end
