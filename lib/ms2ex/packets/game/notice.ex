defmodule Ms2ex.Packets.Notice do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @commands %{
    notice: 4,
    disconnect: 5
  }

  @flags %{
    message: 1,
    alert: 4,
    mint: 16,
    message_box: 64,
    disconnect: 128,
    large_alert: 512,
    banner: 1024
  }

  def message_box(code) do
    text = text_from_code(code)

    __MODULE__
    |> build()
    |> put_byte(@commands.notice)
    |> put_byte(@flags.message_box)
    |> put_text(text)
  end

  defp text_from_code(code) do
    %{
      localized?: true,
      unknown: 1,
      code: code,
      args: [],
      message: ""
    }
  end

  defp put_text(packet, text) do
    packet
    |> put_bool(text.localized?)
    |> put_int(text.unknown)
    |> put_localization(text)
  end

  defp put_localization(packet, %{localized?: true} = text) do
    packet
    |> put_byte(text.code)
    |> put_int(length(text.args))
    |> reduce(text.args, fn arg, packet ->
      put_ustring(packet, arg)
    end)
  end

  defp put_localization(packet, text) do
    put_string(packet, text.message)
  end
end
