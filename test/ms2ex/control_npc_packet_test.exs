defmodule Ms2ex.ControlNpcPacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Types

  # entry layout up to the anim-speed slot: object id int, flags byte,
  # position 3 shorts, rotation short, velocity 3 shorts
  @anim_speed_offset 4 + 1 + 6 + 2 + 6
  # opcode short + npc-count short + entry-length short precede the entry
  @entry_offset 6

  test "a walking npc's animation rate rides its gait speed" do
    npc = npc(%{ani_speed: 1.0}, velocity: {120, 0, 0})

    anim_speed = anim_speed(Packets.ControlNpc.bytes([npc]))

    # the walk cycle must play at the rate the npc covers ground at, else
    # the model glides over its own stride
    assert anim_speed == 12_000
  end

  test "the model's ani_speed factor scales the playback rate" do
    npc = npc(%{ani_speed: 0.65}, velocity: {0, -320, 0})

    assert anim_speed(Packets.ControlNpc.bytes([npc])) == trunc(0.65 * 320 * 100)
  end

  test "a standing npc plays at its bare ani_speed" do
    npc = npc(%{ani_speed: 1.0}, velocity: {0, 0, 0})

    assert anim_speed(Packets.ControlNpc.bytes([npc])) == 100
  end

  test "metadata without ani_speed falls back to 1.0x" do
    npc = npc(%{}, velocity: {120, 0, 0})

    assert anim_speed(Packets.ControlNpc.bytes([npc])) == 12_000
  end

  defp npc(model_meta, attrs) do
    %Types.FieldNpc{
      object_id: 1,
      npc: %Types.Npc{id: 11_003_146, metadata: %{model: model_meta}},
      position: %Types.Coord{x: 100, y: 200, z: 300},
      rotation: %Types.Coord{z: 90.0},
      animation: 13,
      velocity: Keyword.fetch!(attrs, :velocity)
    }
  end

  defp anim_speed(bytes) do
    <<_::binary-size(@entry_offset), entry::binary>> = bytes

    <<_::binary-size(@anim_speed_offset), rate::little-signed-integer-size(16), _::binary>> =
      entry

    rate
  end
end
