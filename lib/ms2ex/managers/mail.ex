defmodule Ms2ex.Managers.Mail do
  @moduledoc """
  Mail flows: sending, collecting attachments and notifications.

  Persistence (mail rows, attachments, read/collected timestamps) lives in
  `Ms2ex.Context.Mails`; this module orchestrates the flows around them —
  validations, wallet credits, inventory transfers, quest notifications and
  the packets the client receives.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @default_expiry_days 30

  @doc "Sends a player-to-player mail."
  def send_player_mail(%Schema.Character{} = sender, receiver_name, title, content) do
    receiver_name = String.trim(receiver_name)

    with :ok <- validate_recipient(sender, receiver_name),
         {:ok, recipient} <- fetch_recipient(receiver_name) do
      case Context.Mails.insert_player_mail(sender, recipient, title, content) do
        {:ok, mail} ->
          notify_recipient(recipient.id)
          {:ok, mail}

        {:error, _changeset} ->
          {:error, :s_mail_error_createmail}
      end
    end
  end

  defp fetch_recipient(receiver_name) do
    case Context.Characters.get_by(name: receiver_name) do
      nil -> {:error, :s_mail_error_username}
      %Schema.Character{} = recipient -> {:ok, recipient}
    end
  end

  defp validate_recipient(_sender, ""), do: {:error, :s_mail_error_username}

  defp validate_recipient(sender, receiver_name) do
    if String.downcase(receiver_name) == String.downcase(sender.name) do
      {:error, :s_mail_error_recipient_equal_sender}
    else
      :ok
    end
  end

  @doc """
  Sends a system mail with optional currency and item attachments.
  """
  def send_system_mail(receiver_id, title, content, opts \\ []) do
    content = system_mail_content(content)
    attrs = system_mail_attrs(receiver_id, title, content, opts)
    items = Keyword.get(opts, :items, [])
    receiver_type = Map.get(attrs, :receiver_type, :character)

    {:ok, mail} = Context.Mails.insert_system_mail(attrs)
    attached = Context.Mails.attach_items_to_mail(mail.id, items)

    if receiver_type == :character, do: notify_recipient(receiver_id)

    {:ok, %{mail | items: attached}}
  end

  defp system_mail_content(content) when is_binary(content), do: content

  defp system_mail_content(content) when is_atom(content) do
    with {:ok, _content} <- Ms2ex.Enums.SystemMailContent.cast(content),
         value when is_integer(value) <- Ms2ex.Enums.SystemMailContent.get_value(content) do
      Integer.to_string(value)
    else
      _ -> raise ArgumentError, "unknown system mail content: #{inspect(content)}"
    end
  end

  defp system_mail_attrs(receiver_id, title, content, opts) do
    expiry_days = Keyword.get(opts, :expires_in_days, @default_expiry_days)
    expires_at = DateTime.utc_now() |> DateTime.add(expiry_days, :day)

    %{
      sender_id: Keyword.get(opts, :sender_id, 0),
      sender_name: Keyword.get(opts, :sender_name, ""),
      receiver_id: receiver_id,
      receiver_type: Keyword.get(opts, :receiver_type, :character),
      type: Keyword.get(opts, :type, :system),
      title: title,
      content: content,
      title_args: Keyword.get(opts, :title_args, []),
      content_args: Keyword.get(opts, :content_args, []),
      wedding_invite: Keyword.get(opts, :wedding_invite, ""),
      mesos: Keyword.get(opts, :mesos, 0),
      merets: Keyword.get(opts, :merets, 0),
      game_merets: Keyword.get(opts, :game_merets, 0),
      expires_at: expires_at
    }
  end

  @doc """
  Collects attachments (currencies and items) from a mail.
  """
  def collect(mail_id, %Schema.Character{} = character) do
    case Context.Mails.get(mail_id, character.id) do
      nil ->
        {:error, :mail_not_found}

      %Schema.Mail{} = mail ->
        with :ok <- Context.Mails.validate_collectible(mail),
             :ok <- validate_inventory_space(mail, character) do
          perform_collect(mail, character)
        end
    end
  end

  @doc """
  Bulk collects attachments from multiple mails.
  """
  def bulk_collect(mail_ids, %Schema.Character{} = character) do
    collected =
      Enum.reduce_while(mail_ids, [], fn mail_id, acc ->
        case collect(mail_id, character) do
          {:ok, mail} -> {:cont, [mail | acc]}
          {:error, _reason} -> {:halt, acc}
        end
      end)

    {:ok, Enum.reverse(collected)}
  end

  @doc """
  Pushes an unread mail notification to an online character.
  """
  def notify_recipient(character_id, alert \\ true) do
    case Managers.Character.lookup(character_id) do
      {:ok, %Schema.Character{sender_session_pid: pid} = rcpt} when not is_nil(pid) ->
        count = Context.Mails.count_unread(character_id)
        push(rcpt, Packets.Mail.notify(count, alert))
        :ok

      _ ->
        :ok
    end
  end

  # ---- collection ----

  defp validate_inventory_space(%Schema.Mail{items: []}, _character), do: :ok

  defp validate_inventory_space(%Schema.Mail{items: items}, %Schema.Character{id: char_id}) do
    items_by_tab =
      Enum.group_by(items, fn item ->
        meta = item.metadata || Context.Items.load_metadata(item).metadata
        Types.Item.inventory_tab(meta)
      end)

    Enum.reduce_while(items_by_tab, :ok, fn {tab, tab_items}, :ok ->
      free_slots = Managers.Inventory.free_slot_count(char_id, tab)

      if length(tab_items) > free_slots do
        {:halt, {:error, :s_mail_error_receiveitem_to_inven}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp perform_collect(%Schema.Mail{} = mail, %Schema.Character{} = character) do
    transfer_mail_currencies(mail, character)

    case transfer_mail_items(mail.items, character) do
      :ok -> Context.Mails.mark_collected(mail)
      {:error, _reason} = error -> error
    end
  end

  defp transfer_mail_currencies(%Schema.Mail{} = mail, %Schema.Character{} = character) do
    if mail.mesos > 0 and is_nil(mail.mesos_collected_at) do
      Managers.Wallet.update(character, :mesos, mail.mesos)
    end

    if mail.merets > 0 and is_nil(mail.merets_collected_at) do
      Managers.Wallet.update(character, :merets, mail.merets)
    end

    if mail.game_merets > 0 and is_nil(mail.game_merets_collected_at) do
      Managers.Wallet.update(character, :game_merets, mail.game_merets)
    end
  end

  defp transfer_mail_items(items, %Schema.Character{} = character) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      item_to_add = %{item | location: :inventory, mail_id: nil, character_id: character.id}

      case Managers.Inventory.add_item(character, item_to_add) do
        {:ok, result} ->
          Managers.Quest.notify_item_acquired(character, item_to_add)
          push(character, Packets.InventoryItem.add_item(result, character))
          push(character, Packets.InventoryItem.mark_item_new(item_to_add))
          Context.Mails.delete_item(item)
          {:cont, :ok}

        {:error, :full_inventory} ->
          {:halt, {:error, :s_mail_error_receiveitem_to_inven}}

        error ->
          {:halt, error}
      end
    end)
  end
end
