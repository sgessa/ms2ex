defmodule Ms2ex.GameHandlers.Mail do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  require Logger

  @batch_size 5

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Load (0x00)
  defp handle_mode(0x00, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      push_mail_list(session, character)
    end
  end

  # Send (0x01)
  defp handle_mode(0x01, packet, session) do
    {receiver_name, packet} = get_ustring(packet)
    {title, packet} = get_ustring(packet)
    {content, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case Context.Mails.send_player_mail(character, receiver_name, title, content) do
        {:ok, mail} ->
          Managers.Quest.update_conditions(character.id, :send_mail, 1, "", 0, "", 0)
          push(session, Packets.Mail.send(mail.id))

        {:error, error_code} ->
          push(session, Packets.Mail.error(error_code))
      end
    end
  end

  # Read (0x02)
  defp handle_mode(0x02, packet, session) do
    {mail_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case Context.Mails.read(mail_id, character) do
        {:ok, mail} ->
          push(session, Packets.Mail.read(mail))

        {:error, error_code} ->
          push(session, Packets.Mail.error(error_code))
      end
    end
  end

  # Collect (0x0B / 11)
  defp handle_mode(0x0B, packet, session) do
    {mail_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case Context.Mails.collect(mail_id, character) do
        {:ok, mail} ->
          session
          |> push(Packets.Mail.collect(mail.id))
          |> push(Packets.Mail.collect_read(mail))

        {:error, error_code} ->
          push(session, Packets.Mail.error(error_code))
      end
    end
  end

  # AdBill (0x0C / 12)
  defp handle_mode(0x0C, packet, session) do
    {mail_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case Context.Mails.get(mail_id, character.id) do
        %Ms2ex.Schema.Mail{} = mail ->
          push(session, Packets.Mail.ad_bill(mail))

        nil ->
          push(session, Packets.Mail.error(:mail_not_found))
      end
    end
  end

  # Delete (0x0D / 13)
  defp handle_mode(0x0D, packet, session) do
    {count, packet} = get_int(packet)
    mail_ids = read_longs(packet, count)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      {:ok, deleted_ids} = Context.Mails.bulk_delete(mail_ids, character.id)

      Enum.each(deleted_ids, fn id ->
        push(session, Packets.Mail.deleted(id))
      end)
    end
  end

  # BulkRead (0x12 / 18)
  defp handle_mode(0x12, packet, session) do
    {count, packet} = get_int(packet)
    mail_ids = read_longs(packet, count)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      {:ok, updated_mails} = Context.Mails.bulk_read(mail_ids, character)

      Enum.each(updated_mails, fn mail ->
        push(session, Packets.Mail.read(mail))
      end)
    end
  end

  # BulkCollect (0x13 / 19)
  defp handle_mode(0x13, packet, session) do
    {count, packet} = get_int(packet)
    mail_ids = read_longs(packet, count)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      {:ok, collected_mails} = Context.Mails.bulk_collect(mail_ids, character)

      Enum.each(collected_mails, fn mail ->
        session
        |> push(Packets.Mail.collect(mail.id))
        |> push(Packets.Mail.collect_read(mail))
      end)
    end
  end

  defp handle_mode(mode, _packet, _session) do
    Logger.warning("Unhandled Mail mode #{inspect(mode)}")
    :ok
  end

  defp read_longs(_packet, count) when count <= 0, do: []

  defp read_longs(packet, count) do
    {ids, _packet} =
      Enum.reduce(1..count, {[], packet}, fn _, {acc, p} ->
        {id, rest} = get_long(p)
        {[id | acc], rest}
      end)

    Enum.reverse(ids)
  end

  defp push_mail_list(session, character) do
    mails = Context.Mails.list(character.id, character.account_id)

    push(session, Packets.Mail.start_list())

    mails
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      push(session, Packets.Mail.load(batch, character))
    end)

    push(session, Packets.Mail.end_list())
  end
end
