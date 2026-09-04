defmodule Ms2ex.Packets.GuideRecord do
  import Ms2ex.Packets.PacketWriter

  # sent on field enter so the client resumes where the character left off
  # instead of replaying guide pop-ups already dismissed
  def load(records) when is_map(records) do
    __MODULE__
    |> build()
    |> put_int(map_size(records))
    |> reduce(records, fn {guide_id, step}, packet ->
      packet
      |> put_int(guide_id)
      |> put_int(step)
    end)
    |> put_byte()
  end

  def load(_records), do: load(%{})
end
