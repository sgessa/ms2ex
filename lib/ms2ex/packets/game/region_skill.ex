defmodule Ms2ex.Packets.RegionSkill do
  alias Ms2ex.{Context, ProtoMetadata, Packets, SkillCast}

  import Packets.PacketWriter

  def add(source_id, effect_position, skill_cast) do
    parent = skill_cast.parent_skill
    magic_path = SkillCast.magic_path(parent)

    moves =
      if length(magic_path.moves) > 0,
        do: magic_path.moves,
        else: [%ProtoMetadata.MagicPathMove{}]

    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(source_id)
    |> put_int(source_id)
    |> put_int()
    |> put_byte(length(moves))
    |> put_moves(moves, effect_position)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_long()
  end

  defp put_moves(packet, [], _effect_position), do: packet

  defp put_moves(packet, [move | moves], effect_position) do
    cast_position = Context.MapBlock.add(move.fire_offset_position, effect_position)

    packet
    |> put_coord(Context.MapBlock.closest_block(cast_position))
    |> put_moves(moves, effect_position)
  end

  def remove(source_id) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_int(source_id)
  end
end
