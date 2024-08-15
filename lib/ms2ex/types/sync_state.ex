defmodule Ms2ex.Types.SyncState do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Packets}
  alias Ms2ex.Types.Coord

  import Bitwise
  import Packets.PacketReader
  import Packets.PacketWriter

  @flags [none: 0, flag1: 1, flag2: 2, flag3: 4, flag4: 8, flag5: 16, flag6: 32]
  @default_coord %Coord{x: 0, y: 0, z: 0}

  schema "virtual: sync_states" do
    field :state, :integer, default: 0
    field :sub_state, :integer, default: 0
    field :animation, :integer, default: 0
    field :flag, :integer, default: 0
    field :position, EctoTypes.Term, default: @default_coord
    field :rotation, :integer, default: 0
    field :unknown_float_1, :float, default: 0.0
    field :unknown_float_2, :float, default: 0.0
    field :speed, EctoTypes.Term, default: @default_coord
    field :unknown1, :integer, default: 0
    field :rotation2, :integer, default: 0
    field :unknown3, :integer, default: 0
    field :sync_number, :integer, default: 0

    # Flags
    field :unknown_flag_1, EctoTypes.Term, default: {0, 0}
    field :unknown_flag_2, EctoTypes.Term, default: {@default_coord, ""}
    field :unknown_flag_3, EctoTypes.Term, default: {0, ""}
    field :flag_4_animation, :string, default: ""
    field :unknown_flag_5, EctoTypes.Term, default: {0, ""}
    field :unknown_flag_6, EctoTypes.Term, default: {0, 0, 0, @default_coord, @default_coord}
  end

  def from_packet(packet) do
    sync_state = %__MODULE__{}

    {state, packet} = get_byte(packet)
    {sub_state, packet} = get_byte(packet)
    {flag, packet} = get_byte(packet)

    sync_state = %{sync_state | state: state, sub_state: sub_state, flag: flag}

    {sync_state, packet} =
      if has_bit?(flag, :flag1) do
        {flag_1_unknown_1, packet} = get_int(packet)
        {flag_1_unknown_2, packet} = get_short(packet)
        {%{sync_state | unknown_flag_1: {flag_1_unknown_1, flag_1_unknown_2}}, packet}
      else
        {sync_state, packet}
      end

    {position, packet} = get_short_coord(packet)
    {rotation, packet} = get_short(packet)
    {animation, packet} = get_byte(packet)

    sync_state = %{sync_state | position: position, rotation: rotation, animation: animation}

    {sync_state, packet} =
      if sync_state.animation > 127 do
        {unknown_float1, packet} = get_float(packet)
        {unknown_float2, packet} = get_float(packet)
        {%{sync_state | unknown_float_1: unknown_float1, unknown_float_2: unknown_float2}, packet}
      else
        {sync_state, packet}
      end

    {speed, packet} = get_short_coord(packet)
    {unknown1, packet} = get_byte(packet)
    {rotation2, packet} = get_short(packet)
    {unknown3, packet} = get_short(packet)

    sync_state = %{
      sync_state
      | speed: speed,
        unknown1: unknown1,
        rotation2: rotation2,
        unknown3: unknown3
    }

    {sync_state, packet} =
      if has_bit?(flag, :flag2) do
        {flag_2_unknown_1, packet} = get_coord(packet)
        {flag_2_unknown_2, packet} = get_ustring(packet)

        {%{sync_state | unknown_flag_2: {flag_2_unknown_1, flag_2_unknown_2}}, packet}
      else
        {sync_state, packet}
      end

    {sync_state, packet} =
      if has_bit?(flag, :flag3) do
        {flag_3_unknown_1, packet} = get_int(packet)
        {flag_3_unknown_2, packet} = get_ustring(packet)

        {%{sync_state | unknown_flag_3: {flag_3_unknown_1, flag_3_unknown_2}}, packet}
      else
        {sync_state, packet}
      end

    {sync_state, packet} =
      if has_bit?(flag, :flag4) do
        {flag_4_animation, packet} = get_ustring(packet)
        {%{sync_state | flag_4_animation: flag_4_animation}, packet}
      else
        {sync_state, packet}
      end

    {sync_state, packet} =
      if has_bit?(flag, :flag5) do
        {flag_5_unknown_1, packet} = get_int(packet)
        {flag_5_unknown_2, packet} = get_ustring(packet)
        {%{sync_state | unknown_flag_5: {flag_5_unknown_1, flag_5_unknown_2}}, packet}
      else
        {sync_state, packet}
      end

    {sync_state, packet} =
      if has_bit?(flag, :flag6) do
        {flag_6_unknown_1, packet} = get_int(packet)
        {flag_6_unknown_2, packet} = get_int(packet)
        {flag_6_unknown_3, packet} = get_byte(packet)
        {flag_6_position, packet} = get_coord(packet)
        {flag_6_rotation, packet} = get_coord(packet)

        unknown_flag_6 =
          {flag_6_unknown_1, flag_6_unknown_2, flag_6_unknown_3, flag_6_position, flag_6_rotation}

        {%{sync_state | unknown_flag_6: unknown_flag_6}, packet}
      else
        {sync_state, packet}
      end

    {sync_number, packet} = get_int(packet)

    {%{sync_state | sync_number: sync_number}, packet}
  end

  def put_state(packet, %{flag: flag} = state) do
    packet =
      packet
      |> put_byte(state.state)
      |> put_byte(state.sub_state)
      |> put_byte(flag)

    packet =
      if has_bit?(flag, :flag1) do
        {flag1_unknown1, flag1_unknown2} = state.unknown_flag_1

        packet
        |> put_int(flag1_unknown1)
        |> put_short(flag1_unknown2)
      else
        packet
      end

    packet =
      packet
      |> put_short_coord(state.position)
      |> put_short(state.rotation)
      |> put_byte(state.animation)

    packet =
      if state.animation > 127 do
        packet
        |> put_float(state.unknown_float_1)
        |> put_float(state.unknown_float_2)
      else
        packet
      end

    packet =
      packet
      |> put_short_coord(state.speed)
      |> put_byte(state.unknown1)
      |> put_short(state.rotation2)
      |> put_short(state.unknown3)

    packet =
      if has_bit?(flag, :flag2) do
        {coord, str} = state.unknown_flag_2

        packet
        |> put_coord(coord)
        |> put_ustring(str)
      else
        packet
      end

    packet =
      if has_bit?(flag, :flag3) do
        {int, str} = state.unknown_flag_3

        packet
        |> put_int(int)
        |> put_ustring(str || "")
      else
        packet
      end

    packet =
      if has_bit?(flag, :flag4) do
        put_ustring(packet, state.flag_4_animation)
      else
        packet
      end

    packet =
      if has_bit?(flag, :flag5) do
        {int, str} = state.unknown_flag_5

        packet
        |> put_int(int)
        |> put_ustring(str || "")
      else
        packet
      end

    packet =
      if has_bit?(flag, :flag6) do
        {int1, int2, int3, position, rotation} = state.unknown_flag_6

        packet
        |> put_int(int1)
        |> put_int(int2)
        |> put_byte(int3)
        |> put_coord(position)
        |> put_coord(rotation)
      else
        packet
      end

    put_int(packet, state.sync_number)
  end

  def has_bit?(flag, bit), do: (flag &&& flag(bit)) != 0

  defp flag(flag), do: Keyword.get(@flags, flag)
end
