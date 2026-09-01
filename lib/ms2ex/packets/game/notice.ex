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

  def message(msg, flags \\ nil) when is_binary(msg) do
    flags = flags || @flags.message

    text = %{
      localized?: false,
      unknown: if(String.starts_with?(msg, "s_"), do: 5, else: 0),
      message: msg
    }

    __MODULE__
    |> build()
    |> put_byte(@commands.notice)
    |> put_short(flags)
    |> put_text(text)
  end

  @doc "Sends a localised message-box notice (uses a StringCode integer)."
  def message_box(code) do
    text = %{
      localized?: true,
      unknown: 1,
      code: code,
      args: []
    }

    __MODULE__
    |> build()
    |> put_byte(@commands.notice)
    |> put_short(@flags.message_box)
    |> put_text(text)
  end

  defp put_text(packet, text) do
    packet
    |> put_bool(text.localized?)
    |> put_int(text.unknown)
    |> put_localization(text)
  end

  defp put_localization(packet, %{localized?: true} = text) do
    packet
    |> put_int(text.code)
    |> put_int(length(text.args))
    |> reduce(text.args, fn arg, p -> put_ustring(p, arg) end)
  end

  defp put_localization(packet, %{message: msg}) do
    put_ustring(packet, msg)
  end
end
