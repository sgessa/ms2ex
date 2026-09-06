defmodule Ms2ex.Packets.Mail do
  @moduledoc """
  Packet serializer for the Mail System (SendOp 0x55).
  """

  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Ms2ex.Packets.PacketWriter

  @commands %{
    load: 0x00,
    send: 0x01,
    read: 0x02,
    returned: 0x03,
    collect: 0x0A,
    collect_read: 0x0B,
    ad_bill: 0x0C,
    deleted: 0x0D,
    notify: 0x0E,
    notify_temporary: 0x0F,
    start_list: 0x10,
    end_list: 0x11,
    error: 0x14,
    gift: 0x16
  }

  def start_list do
    __MODULE__
    |> build()
    |> put_byte(@commands.start_list)
  end

  def end_list do
    __MODULE__
    |> build()
    |> put_byte(@commands.end_list)
  end

  def load(mails, %Schema.Character{} = character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.load)
    |> put_int(length(mails))
    |> reduce(mails, fn mail, packet ->
      put_mail(packet, mail, character)
    end)
  end

  def send(mail_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.send)
    |> put_long(mail_id)
  end

  def read(%Schema.Mail{} = mail) do
    __MODULE__
    |> build()
    |> put_byte(@commands.read)
    |> put_long(mail.id)
    |> put_long(unix_or_zero(mail.read_at))
  end

  def collect(mail_id, success \\ true) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@commands.collect)
      |> put_long(mail_id)
      |> put_bool(success)

    if success do
      packet
      |> put_byte(0)
      |> put_long(DateTime.utc_now() |> DateTime.to_unix())
    else
      packet
    end
  end

  def collect_read(%Schema.Mail{} = mail) do
    __MODULE__
    |> build()
    |> put_byte(@commands.collect_read)
    |> put_long(mail.id)
    |> put_long(unix_or_zero(mail.read_at))
  end

  def ad_bill(%Schema.Mail{} = mail) do
    __MODULE__
    |> build()
    |> put_byte(@commands.ad_bill)
    |> put_long(mail.id)
    |> put_long(0)
  end

  def deleted(mail_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.deleted)
    |> put_long(mail_id)
  end

  def notify(unread_count \\ 0, alert \\ false) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify)
    |> put_int(unread_count)
    |> put_bool(alert)
    |> put_int(unread_count)
  end

  def notify_temporary do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_temporary)
  end

  def error(error_code, code \\ 0) do
    error_val =
      if is_atom(error_code) do
        Enums.MailError.get_value(error_code) || 255
      else
        error_code
      end

    __MODULE__
    |> build()
    |> put_byte(@commands.error)
    |> put_byte(code)
    |> put_byte(error_val)
  end

  # ---- Internal Serializer ----

  defp put_mail(packet, %Schema.Mail{} = mail, character) do
    type_val = Enums.MailType.get_value(mail.type) || 1

    packet
    |> put_byte(type_val)
    |> put_long(mail.id)
    |> put_long(mail.sender_id)
    |> put_ustring(mail.sender_name)
    |> put_ustring(mail.title)
    |> put_ustring(mail.content)
    |> put_ustring(format_args(mail.title_args))
    |> put_ustring(format_args(mail.content_args))
    |> put_mail_items(mail, character)
    |> put_long(mail.mesos)
    |> put_long(unix_or_zero(mail.mesos_collected_at))
    |> put_long(mail.merets)
    |> put_long(unix_or_zero(mail.merets_collected_at))
    |> put_long(mail.game_merets)
    |> put_long(unix_or_zero(mail.game_merets_collected_at))
    |> put_byte(0)
    |> put_long(unix_or_zero(mail.read_at))
    |> put_long(unix_or_zero(mail.expires_at))
    |> put_long(unix_or_zero(mail.inserted_at))
    |> put_ustring(mail.wedding_invite)
  end

  defp put_mail_items(packet, %Schema.Mail{type: :ad}, _character) do
    packet
    |> put_byte(0)
    |> put_ustring()
    |> put_long()
    |> put_byte()
  end

  defp put_mail_items(packet, %Schema.Mail{items: items}, character) do
    packet
    |> put_byte(length(items))
    |> reduce(Enum.with_index(items), fn {item, index}, packet ->
      packet
      |> put_int(item.item_id)
      |> put_long(item.id)
      |> put_byte(index)
      |> put_int(item.rarity)
      |> put_int(item.amount)
      |> put_long()
      |> put_int()
      |> put_long()
      |> Packets.InventoryItem.put_item(item, character)
    end)
  end

  defp format_args(args) when is_list(args) and args != [] do
    body =
      Enum.map_join(args, fn
        {k, v} ->
          key_attr = if k != "" and k != nil, do: to_string(k), else: "key"
          ~s(<v #{key_attr}="#{v}" />)

        [k, v] ->
          key_attr = if k != "" and k != nil, do: to_string(k), else: "key"
          ~s(<v #{key_attr}="#{v}" />)

        _ ->
          ""
      end)

    if body != "", do: "<ms2>" <> body <> "</ms2>", else: ""
  end

  defp format_args(_), do: ""

  defp unix_or_zero(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp unix_or_zero(_), do: 0
end
