defmodule Ms2ex.Context.Mails do
  @moduledoc """
  Context module for the Mail System.
  Manages player-to-player mail, system mail, attachments, and collection.
  """

  import Ecto.Query

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @default_expiry_days 30

  @doc """
  Binds all account-level mails to the given character.
  """
  @spec bind_account_mails(integer(), integer()) :: {integer(), nil | [term()]}
  def bind_account_mails(account_id, character_id) do
    Schema.Mail
    |> where([m], m.receiver_id == ^account_id and m.receiver_type == :account)
    |> Repo.update_all(set: [receiver_id: character_id, receiver_type: :character])
  end

  @doc """
  Lists all non-expired mails for a character, preloading their items.
  """
  @spec list(integer(), integer() | nil) :: [Schema.Mail.t()]
  def list(character_id, account_id \\ nil) do
    if account_id do
      bind_account_mails(account_id, character_id)
    end

    now = DateTime.utc_now()

    Schema.Mail
    |> where(
      [m],
      m.receiver_id == ^character_id and m.receiver_type == :character and m.expires_at > ^now
    )
    |> order_by([m], desc: m.inserted_at, desc: m.id)
    |> preload(:items)
    |> Repo.all()
    |> Enum.map(&load_mail_items_metadata/1)
  end

  @doc """
  Counts unread non-expired mails for a character.
  """
  @spec count_unread(integer()) :: non_neg_integer()
  def count_unread(character_id) do
    now = DateTime.utc_now()

    Schema.Mail
    |> where(
      [m],
      m.receiver_id == ^character_id and m.receiver_type == :character and is_nil(m.read_at) and
        m.expires_at > ^now
    )
    |> select([m], count(m.id))
    |> Repo.one() || 0
  end

  @doc """
  Gets a single mail by ID for a character.
  """
  @spec get(integer(), integer()) :: Schema.Mail.t() | nil
  def get(mail_id, character_id) do
    Schema.Mail
    |> where(
      [m],
      m.id == ^mail_id and m.receiver_id == ^character_id and m.receiver_type == :character
    )
    |> preload(:items)
    |> Repo.one()
    |> case do
      nil -> nil
      mail -> load_mail_items_metadata(mail)
    end
  end

  @doc """
  Sends a player-to-player mail.
  """
  @spec send_player_mail(Schema.Character.t(), String.t(), String.t(), String.t()) ::
          {:ok, Schema.Mail.t()} | {:error, atom()}
  def send_player_mail(%Schema.Character{} = sender, receiver_name, title, content) do
    receiver_name = String.trim(receiver_name)

    with :ok <- validate_recipient(sender, receiver_name),
         %Schema.Character{} = recipient <- get_recipient(receiver_name) do
      create_player_mail(sender, recipient, title, content)
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

  defp get_recipient(receiver_name) do
    case Context.Characters.get_by(name: receiver_name) do
      nil -> {:error, :s_mail_error_username}
      %Schema.Character{} = recipient -> recipient
    end
  end

  defp create_player_mail(sender, recipient, title, content) do
    attrs = %{
      sender_id: sender.id,
      sender_name: sender.name,
      receiver_id: recipient.id,
      receiver_type: :character,
      type: :player,
      title: title,
      content: content,
      expires_at: DateTime.utc_now() |> DateTime.add(@default_expiry_days, :day)
    }

    case %Schema.Mail{} |> Schema.Mail.changeset(attrs) |> Repo.insert() do
      {:ok, mail} ->
        notify_recipient(recipient.id)
        {:ok, %{mail | items: []}}

      {:error, _changeset} ->
        {:error, :s_mail_error_createmail}
    end
  end

  @doc """
  Sends a system mail with optional currency and item attachments.
  """
  @spec send_system_mail(integer(), String.t(), String.t(), keyword()) ::
          {:ok, Schema.Mail.t()} | {:error, atom()}
  def send_system_mail(receiver_id, title, content, opts \\ []) do
    mail_attrs = build_system_mail_attrs(receiver_id, title, content, opts)
    items = Keyword.get(opts, :items, [])
    receiver_type = Map.get(mail_attrs, :receiver_type, :character)

    Repo.transaction(fn ->
      do_send_system_mail(receiver_id, receiver_type, mail_attrs, items)
    end)
  end

  defp do_send_system_mail(receiver_id, receiver_type, mail_attrs, items) do
    case insert_system_mail(mail_attrs) do
      {:ok, mail} ->
        attached = attach_items_to_mail(mail.id, items)
        if receiver_type == :character, do: notify_recipient(receiver_id)
        %{mail | items: attached}

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp build_system_mail_attrs(receiver_id, title, content, opts) do
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

  defp insert_system_mail(attrs) do
    %Schema.Mail{}
    |> Schema.Mail.changeset(attrs)
    |> Repo.insert()
  end

  defp attach_items_to_mail(mail_id, items) do
    Enum.map(items, &attach_item_to_mail(mail_id, &1))
  end

  defp attach_item_to_mail(mail_id, %Schema.Item{id: id} = item)
       when is_integer(id) and id > 0 do
    attrs = %{mail_id: mail_id, location: :mail, character_id: nil, inventory_slot: nil}
    {:ok, updated} = Context.Inventory.update_item(item, attrs)
    updated
  end

  defp attach_item_to_mail(mail_id, item) do
    rarity = Map.get(item, :rarity) || 1
    meta = Map.get(item, :metadata) || %{}
    tab = Map.get(item, :inventory_tab) || Types.Item.inventory_tab(meta)

    attrs =
      item
      |> Map.put(:mail_id, mail_id)
      |> Map.put(:location, :mail)
      |> Map.put(:character_id, nil)
      |> Map.put(:inventory_slot, nil)
      |> Map.put(:inventory_tab, tab)
      |> Map.put(:rarity, rarity)
      |> Map.from_struct()

    {:ok, inserted} =
      %Schema.Item{}
      |> Schema.Item.changeset(attrs)
      |> Repo.insert()

    %{inserted | metadata: meta}
  end

  @doc """
  Marks a mail as read.
  """
  @spec read(integer(), Schema.Character.t()) :: {:ok, Schema.Mail.t()} | {:error, atom()}
  def read(mail_id, %Schema.Character{id: character_id}) do
    case get(mail_id, character_id) do
      nil ->
        {:error, :mail_not_found}

      %Schema.Mail{read_at: read_at} = mail when not is_nil(read_at) ->
        {:ok, mail}

      %Schema.Mail{} = mail ->
        now = DateTime.utc_now()

        mail
        |> Schema.Mail.changeset(%{read_at: now})
        |> Repo.update()
    end
  end

  @doc """
  Bulk marks multiple mails as read.
  """
  @spec bulk_read([integer()], Schema.Character.t()) :: {:ok, [Schema.Mail.t()]}
  def bulk_read(mail_ids, %Schema.Character{id: character_id}) do
    now = DateTime.utc_now()

    Schema.Mail
    |> where(
      [m],
      m.id in ^mail_ids and m.receiver_id == ^character_id and m.receiver_type == :character and
        is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: now])

    updated_mails =
      mail_ids
      |> Enum.map(&get(&1, character_id))
      |> Enum.reject(&is_nil/1)

    {:ok, updated_mails}
  end

  @doc """
  Collects attachments (currencies and items) from a mail.
  """
  @spec collect(integer(), Schema.Character.t()) :: {:ok, Schema.Mail.t()} | {:error, atom()}
  def collect(mail_id, %Schema.Character{} = character) do
    case get(mail_id, character.id) do
      nil ->
        {:error, :mail_not_found}

      %Schema.Mail{} = mail ->
        with :ok <- validate_collectible(mail),
             :ok <- validate_inventory_space(mail, character) do
          perform_collect(mail, character)
        end
    end
  end

  @doc """
  Bulk collects attachments from multiple mails.
  """
  @spec bulk_collect([integer()], Schema.Character.t()) :: {:ok, [Schema.Mail.t()]}
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
  Deletes a mail if it has no uncollected attachments.
  """
  @spec delete(integer(), integer()) :: {:ok, integer()} | {:error, atom()}
  def delete(mail_id, character_id) do
    case get(mail_id, character_id) do
      nil -> {:error, :mail_not_found}
      %Schema.Mail{} = mail -> perform_delete(mail)
    end
  end

  defp perform_delete(%Schema.Mail{} = mail) do
    if can_delete?(mail) do
      case Repo.delete(mail) do
        {:ok, _deleted} -> {:ok, mail.id}
        {:error, _} -> {:error, :s_mail_error}
      end
    else
      {:error, :s_mail_error_already_receive}
    end
  end

  @doc """
  Bulk deletes multiple mails that are eligible for deletion.
  """
  @spec bulk_delete([integer()], integer()) :: {:ok, [integer()]}
  def bulk_delete(mail_ids, character_id) do
    deleted_ids =
      Enum.reduce(mail_ids, [], fn mail_id, acc ->
        case delete(mail_id, character_id) do
          {:ok, id} -> [id | acc]
          _ -> acc
        end
      end)

    {:ok, Enum.reverse(deleted_ids)}
  end

  @doc """
  Pushes an unread mail notification to an online character.
  """
  @spec notify_recipient(integer(), boolean()) :: :ok
  def notify_recipient(character_id, alert \\ true) do
    case Managers.Character.lookup(character_id) do
      {:ok, %Schema.Character{sender_session_pid: pid} = rcpt} when not is_nil(pid) ->
        count = count_unread(character_id)
        SenderSession.push(rcpt, Packets.Mail.notify(count, alert))
        :ok

      _ ->
        :ok
    end
  end

  # ---- Helpers ----

  defp load_mail_items_metadata(%Schema.Mail{items: items} = mail) do
    loaded_items =
      Enum.map(items, fn item ->
        if item.metadata, do: item, else: Context.Items.load_metadata(item)
      end)

    %{mail | items: loaded_items}
  end

  defp validate_collectible(%Schema.Mail{} = mail) do
    now = DateTime.utc_now()

    cond do
      DateTime.compare(now, mail.expires_at) == :gt ->
        {:error, :s_mail_error_receive_expired}

      mesos_collected?(mail) and merets_collected?(mail) and game_merets_collected?(mail) and
          mail.items == [] ->
        {:error, :s_mail_error_already_receive}

      true ->
        :ok
    end
  end

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
    transfer_mail_items(mail.items, character)
    update_mail_collected(mail)
  end

  defp transfer_mail_currencies(%Schema.Mail{} = mail, %Schema.Character{} = character) do
    if mail.mesos > 0 and is_nil(mail.mesos_collected_at) do
      Context.Wallets.update(character, :mesos, mail.mesos)
    end

    if mail.merets > 0 and is_nil(mail.merets_collected_at) do
      Context.Wallets.update(character, :merets, mail.merets)
    end

    if mail.game_merets > 0 and is_nil(mail.game_merets_collected_at) do
      Context.Wallets.update(character, :game_merets, mail.game_merets)
    end
  end

  defp transfer_mail_items(items, %Schema.Character{} = character) do
    Enum.each(items, fn item ->
      item_to_add = %{item | location: :inventory, mail_id: nil, character_id: character.id}
      {:ok, result} = Managers.Inventory.add_item(character, item_to_add)
      Managers.Quest.notify_item_acquired(character, item_to_add)

      SenderSession.push(character, Packets.InventoryItem.add_item(result, character))
      SenderSession.push(character, Packets.InventoryItem.mark_item_new(item_to_add))

      Repo.delete(item)
    end)
  end

  defp update_mail_collected(%Schema.Mail{} = mail) do
    now = DateTime.utc_now()
    changes = build_collect_changes(mail, now)

    case mail |> Schema.Mail.changeset(changes) |> Repo.update() do
      {:ok, updated_mail} -> {:ok, %{updated_mail | items: []}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp build_collect_changes(%Schema.Mail{} = mail, now) do
    %{
      read_at: mail.read_at || now,
      mesos_collected_at: collect_timestamp(mail.mesos, mail.mesos_collected_at, now),
      merets_collected_at: collect_timestamp(mail.merets, mail.merets_collected_at, now),
      game_merets_collected_at:
        collect_timestamp(mail.game_merets, mail.game_merets_collected_at, now)
    }
  end

  defp collect_timestamp(amount, nil, now) when amount > 0, do: now
  defp collect_timestamp(_amount, existing, _now), do: existing

  defp can_delete?(%Schema.Mail{} = mail) do
    mesos_collected?(mail) and merets_collected?(mail) and game_merets_collected?(mail) and
      mail.items == []
  end

  defp mesos_collected?(%Schema.Mail{mesos: 0}), do: true
  defp mesos_collected?(%Schema.Mail{mesos_collected_at: t}) when not is_nil(t), do: true
  defp mesos_collected?(_), do: false

  defp merets_collected?(%Schema.Mail{merets: 0}), do: true
  defp merets_collected?(%Schema.Mail{merets_collected_at: t}) when not is_nil(t), do: true
  defp merets_collected?(_), do: false

  defp game_merets_collected?(%Schema.Mail{game_merets: 0}), do: true

  defp game_merets_collected?(%Schema.Mail{game_merets_collected_at: t}) when not is_nil(t),
    do: true

  defp game_merets_collected?(_), do: false
end
