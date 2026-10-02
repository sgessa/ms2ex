defmodule Ms2ex.Context.Mails do
  @moduledoc """
  Context module for the Mail System: mail rows, attachments and their
  read/collected timestamps. Sending and collection flows live in
  `Ms2ex.Managers.Mail`.
  """

  import Ecto.Query

  alias Ms2ex.Context
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
  Inserts a player-to-player mail row.
  """
  @spec insert_player_mail(Schema.Character.t(), Schema.Character.t(), String.t(), String.t()) ::
          {:ok, Schema.Mail.t()} | {:error, atom()}
  def insert_player_mail(sender, recipient, title, content) do
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
      {:ok, mail} -> {:ok, %{mail | items: []}}
      {:error, _changeset} -> {:error, :s_mail_error_createmail}
    end
  end

  @doc """
  Inserts a system mail row.
  """
  @spec insert_system_mail(map()) :: {:ok, Schema.Mail.t()} | {:error, term()}
  def insert_system_mail(attrs) do
    %Schema.Mail{}
    |> Schema.Mail.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Attaches item rows to a mail (moved out of the character's inventory).
  """
  def attach_items_to_mail(mail_id, items) do
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
  Whether a mail can still be collected (not expired, attachments pending).
  Returns `:ok` or `{:error, code}`.
  """
  def validate_collectible(%Schema.Mail{} = mail) do
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

  # ---- Helpers ----

  defp load_mail_items_metadata(%Schema.Mail{items: items} = mail) do
    loaded_items =
      Enum.map(items, fn item ->
        if item.metadata, do: item, else: Context.Items.load_metadata(item)
      end)

    %{mail | items: loaded_items}
  end

  @doc """
  Marks a mail's attachments as collected.
  """
  def mark_collected(%Schema.Mail{} = mail) do
    now = DateTime.utc_now()
    changes = build_collect_changes(mail, now)

    case mail |> Schema.Mail.changeset(changes) |> Repo.update() do
      {:ok, updated_mail} -> {:ok, %{updated_mail | items: []}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a detached attachment item row after it moved to the inventory.
  """
  def delete_item(%Schema.Item{} = item), do: Repo.delete(item)

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
