defmodule Ms2ex.Packets.SmartPush do
  alias Ms2ex.Enums

  import Ms2ex.Packets.PacketWriter

  @modes %{
    activate: 0x1
  }

  def activate_effect(currency_type, buff_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.activate)
    |> put_int(Enums.SmartPushCurrencyType.get_value(currency_type))
    |> put_int(buff_id)
  end

  def activate_gather(smart_push_id, amount) do
    __MODULE__
    |> build()
    |> put_byte(@modes.activate)
    |> put_int(smart_push_id)
    |> put_int(amount)
  end
end
