defmodule Ms2ex.MailTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  @potion_id 5_000_001
  @gear_id 5_000_002

  setup do
    stub_metadata(%{
      "item:#{@potion_id}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 0, subtype: 2},
        slot_names: [],
        stack_limit: 10,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:#{@gear_id}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [5],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    sender = insert_character("MailSender")
    receiver = insert_character("MailReceiver")

    Repo.insert!(%Schema.InventoryTab{character_id: receiver.id, tab: :consumable, slots: 84})
    Repo.insert!(%Schema.InventoryTab{character_id: receiver.id, tab: :gear, slots: 10})

    Managers.Character.start(sender)
    Managers.Character.start(receiver)
    start_inventory(receiver)

    %{sender: sender, receiver: receiver}
  end

  describe "sending mail" do
    test "player sends mail to another player successfully", %{sender: sender, receiver: receiver} do
      assert {:ok, mail} =
               Context.Mails.send_player_mail(sender, receiver.name, "Hello!", "How are you?")

      assert mail.sender_id == sender.id
      assert mail.sender_name == sender.name
      assert mail.receiver_id == receiver.id
      assert mail.receiver_type == :character
      assert mail.type == :player
      assert mail.title == "Hello!"
      assert mail.content == "How are you?"
      assert is_nil(mail.read_at)
      assert not is_nil(mail.expires_at)

      assert Context.Mails.count_unread(receiver.id) == 1
    end

    test "cannot send mail to non-existent player", %{sender: sender} do
      assert {:error, :s_mail_error_username} =
               Context.Mails.send_player_mail(sender, "NonExistentUser999", "Hi", "Msg")
    end

    test "cannot send mail to oneself", %{sender: sender} do
      assert {:error, :s_mail_error_recipient_equal_sender} =
               Context.Mails.send_player_mail(sender, sender.name, "Self", "Self")
    end

    test "system mail can be sent with currencies and items", %{receiver: receiver} do
      item = Context.Items.init(@potion_id, %{amount: 5})

      assert {:ok, mail} =
               Context.Mails.send_system_mail(receiver.id, "Reward", "Here is your gift",
                 sender_name: "Admin",
                 mesos: 10_000,
                 merets: 50,
                 items: [item]
               )

      assert mail.type == :system
      assert mail.sender_name == "Admin"
      assert mail.mesos == 10_000
      assert mail.merets == 50
      assert length(mail.items) == 1
      assert List.first(mail.items).item_id == @potion_id
      assert List.first(mail.items).amount == 5
    end
  end

  describe "reading mail" do
    test "reading an unread mail marks it as read", %{sender: sender, receiver: receiver} do
      {:ok, mail} = Context.Mails.send_player_mail(sender, receiver.name, "Test", "Content")

      assert {:ok, read_mail} = Context.Mails.read(mail.id, receiver)
      assert not is_nil(read_mail.read_at)
      assert Context.Mails.count_unread(receiver.id) == 0

      # Reading again returns ok with same read_at
      assert {:ok, _} = Context.Mails.read(mail.id, receiver)
    end

    test "bulk reading marks multiple mails as read", %{sender: sender, receiver: receiver} do
      {:ok, m1} = Context.Mails.send_player_mail(sender, receiver.name, "T1", "C1")
      {:ok, m2} = Context.Mails.send_player_mail(sender, receiver.name, "T2", "C2")

      assert Context.Mails.count_unread(receiver.id) == 2
      assert {:ok, updated} = Context.Mails.bulk_read([m1.id, m2.id], receiver)
      assert length(updated) == 2
      assert Context.Mails.count_unread(receiver.id) == 0
    end
  end

  describe "collecting attachments" do
    test "collects mesos, merets, and items into inventory and wallet", %{receiver: receiver} do
      item = Context.Items.init(@potion_id, %{amount: 5})

      {:ok, mail} =
        Context.Mails.send_system_mail(receiver.id, "Loot", "Attachments",
          mesos: 5000,
          merets: 100,
          items: [item]
        )

      assert {:ok, collected_mail} = Context.Mails.collect(mail.id, receiver)
      assert not is_nil(collected_mail.mesos_collected_at)
      assert not is_nil(collected_mail.merets_collected_at)

      # Check wallet (initial 10,000 + 5,000 = 15,000)
      wallet = Context.Wallets.find(receiver)
      assert wallet.mesos == 15_000

      # Check account wallet (initial 100 + 100 = 200)
      account_wallet = Schema.AccountWallet |> Repo.get_by(account_id: receiver.account_id)
      assert account_wallet.merets == 200

      # Check inventory has the item
      inventory_items = Managers.Inventory.list_tab_items(receiver.id, :consumable)
      assert Enum.any?(inventory_items, &(&1.item_id == @potion_id and &1.amount == 5))

      # Cannot collect again
      assert {:error, :s_mail_error_already_receive} = Context.Mails.collect(mail.id, receiver)
    end

    test "cannot collect when inventory is full", %{receiver: receiver} do
      gear = Context.Items.init(@gear_id, %{amount: 1})

      # Fill all 10 gear slots
      Enum.each(1..10, fn _ -> add_item(receiver, @gear_id, 1) end)

      {:ok, mail} =
        Context.Mails.send_system_mail(receiver.id, "Gear", "Full inven test", items: [gear])

      assert {:error, :s_mail_error_receiveitem_to_inven} =
               Context.Mails.collect(mail.id, receiver)
    end
  end

  describe "deleting mail" do
    test "cannot delete mail with uncollected attachments", %{receiver: receiver} do
      {:ok, mail} =
        Context.Mails.send_system_mail(receiver.id, "Money", "Take it", mesos: 1000)

      assert {:error, :s_mail_error_already_receive} = Context.Mails.delete(mail.id, receiver.id)
    end

    test "deletes plain mail or collected mail", %{sender: sender, receiver: receiver} do
      {:ok, mail} = Context.Mails.send_player_mail(sender, receiver.name, "Chat", "No loot")

      assert {:ok, deleted_id} = Context.Mails.delete(mail.id, receiver.id)
      assert deleted_id == mail.id
      assert is_nil(Context.Mails.get(mail.id, receiver.id))
    end
  end

  describe "account mail binding" do
    test "binds account level mail to character", %{receiver: receiver} do
      {:ok, mail} =
        Context.Mails.send_system_mail(receiver.account_id, "Welcome", "Welcome to server",
          receiver_type: :account
        )

      assert mail.receiver_type == :account

      # Before binding, character list doesn't show it
      assert Context.Mails.list(receiver.id) == []

      # List with account_id binds it
      mails = Context.Mails.list(receiver.id, receiver.account_id)
      assert length(mails) == 1
      assert List.first(mails).id == mail.id
      assert List.first(mails).receiver_type == :character
      assert List.first(mails).receiver_id == receiver.id
    end
  end

  describe "packets" do
    test "serializes mail packets properly", %{sender: sender, receiver: receiver} do
      {:ok, mail} = Context.Mails.send_player_mail(sender, receiver.name, "Title", "Body")

      assert is_binary(Packets.Mail.start_list())
      assert is_binary(Packets.Mail.end_list())
      assert is_binary(Packets.Mail.load([mail], receiver))
      assert is_binary(Packets.Mail.send(mail.id))
      assert is_binary(Packets.Mail.read(mail))
      assert is_binary(Packets.Mail.collect(mail.id, true))
      assert is_binary(Packets.Mail.collect_read(mail))
      assert is_binary(Packets.Mail.deleted(mail.id))
      assert is_binary(Packets.Mail.notify(1, true))
      assert is_binary(Packets.Mail.error(:s_mail_error_username))
    end
  end

  describe "handler dispatch" do
    test "handles load, read, delete commands", %{sender: sender, receiver: receiver} do
      session = %Ms2ex.Net.Session{
        character_id: receiver.id,
        sender_pid: self()
      }

      {:ok, mail} = Context.Mails.send_player_mail(sender, receiver.name, "Hi", "Content")

      # Load (0x00)
      Ms2ex.GameHandlers.Mail.handle(<<0x00>>, session)
      assert_receive {:push, _start_list}
      assert_receive {:push, _load}
      assert_receive {:push, _end_list}

      # Read (0x02)
      packet = <<0x02, mail.id::little-64>>
      Ms2ex.GameHandlers.Mail.handle(packet, session)
      assert_receive {:push, _read_pkt}

      # Delete (0x0D)
      del_packet = <<0x0D, 1::little-32, mail.id::little-64>>
      Ms2ex.GameHandlers.Mail.handle(del_packet, session)
      assert_receive {:push, _del_pkt}
    end
  end

  # ---- Helpers ----

  defp insert_character(name) do
    unique = System.unique_integer([:positive])

    account =
      Repo.insert!(%Schema.Account{
        username: "acc_#{name}_#{unique}",
        password_hash: "hash"
      })

    Repo.insert!(%Schema.AccountWallet{account_id: account.id})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "#{name}#{unique}",
        gender: :male,
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: %{}
      })

    Repo.insert!(%Schema.Wallet{character_id: character.id})
    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    %{character | stats: stats, sender_session_pid: self()}
  end

  defp start_inventory(character) do
    :ok = Managers.Inventory.start(character)
    on_exit(fn -> Managers.Inventory.stop(character.id) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), :erlang.whereis(:"inventories:#{character.id}"))
  end

  defp add_item(character, item_id, amount) do
    item =
      Context.Items.init(item_id, %{
        amount: amount,
        inventory_tab: :gear,
        transfer_flags: [:split, :trade]
      })

    {:ok, {_, item}} = Managers.Inventory.add_item(character, item)
    item
  end
end
