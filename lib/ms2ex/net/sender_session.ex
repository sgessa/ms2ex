defmodule Ms2ex.Net.SenderSession do
  use GenServer

  require Logger, as: L

  alias Ms2ex.Crypto.SendCipher
  alias Ms2ex.{CharacterManager, Context, GroupChat, Net, Packets, PartyServer, Schema}
  alias Ms2ex.Packets.{PacketReader, RequestVersion}

  import Net.Utils

  def start_link(socket, transport, send_cipher, parent_pid) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [socket, transport, send_cipher, parent_pid])
    pid
  end

  # Client

  def handshake(pid, recv_cipher) do
    GenServer.cast(pid, {:handshake, recv_cipher})
  end

  def push(%Schema.Character{} = character, packet) when is_binary(packet) do
    push(character.sender_session_pid, packet)
  end

  def push(%Net.Session{} = session, packet) when is_binary(packet) do
    push(session.sender_pid, packet)
    session
  end

  def push(pid, packet) when is_pid(pid) and is_binary(packet) do
    send(pid, {:push, packet})
  end

  def push_notice(session, character, notice) do
    push(session, Packets.UserChat.bytes(:notice_alert, character, notice))
  end

  def run(%Net.Session{sender_pid: pid}, fun) when is_function(fun) do
    GenServer.call(pid, {:run, fun})
  end

  def run(%Schema.Character{sender_session_pid: pid}, fun) when is_function(fun) do
    GenServer.call(pid, {:run, fun})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server

  @impl GenServer
  def init([socket, transport, send_cipher, parent_pid]) do
    state = %{
      socket: socket,
      transport: transport,
      send_cipher: send_cipher,
      parent_pid: parent_pid
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:run, fun}, _from, state) do
    {:reply, fun.(), state}
  end

  @impl true
  def handle_cast({:handshake, recv_cipher}, state) do
    %{send_cipher: send_cipher, socket: socket} = state
    packet = RequestVersion.build(conf()[:version], recv_cipher, send_cipher, conf()[:block_iv])
    {send_cipher, packet} = SendCipher.write_header(send_cipher, packet)

    log_sent_packet(:handshake, packet)
    state.transport.send(socket, packet)

    {:noreply, %{state | send_cipher: send_cipher}}
  end

  @impl true
  def handle_info({:push, packet}, state) do
    %{send_cipher: cipher, socket: socket, transport: transport} = state

    {opcode, data} = PacketReader.get_short(packet)
    log_sent_packet(opcode, data)

    {cipher, enc_packet} = SendCipher.encrypt(cipher, packet)
    transport.send(socket, enc_packet)

    {:noreply, %{state | send_cipher: cipher}}
  end

  def handle_info({:join_group_chat, inviter, rcpt, chat}, state) do
    GroupChat.subscribe(chat)
    chat = GroupChat.load_members(chat)

    send(self(), {:push, Packets.GroupChat.update(chat)})
    send(self(), {:push, Packets.GroupChat.join(inviter, rcpt, chat)})

    {:noreply, state}
  end

  def handle_info({:friend_presence, data}, state) do
    friend = Context.Friends.get_by_character_and_shared_id(data.character.id, data.shared_id)
    friend = Map.put(friend, :rcpt, data.character)

    send(self(), {:push, Packets.Friend.update(friend)})
    send(self(), {:push, Packets.Friend.presence_notification(friend)})

    {:noreply, state}
  end

  def handle_info({:summon, character, map_id}, state) do
    {:noreply, Ms2ex.Field.change_field(character, map_id), state}
  end

  def handle_info({:disband_party, character}, state) do
    PartyServer.unsubscribe(character.party_id)
    send(self(), {:push, Packets.Party.disband()})

    character = %{character | party_id: nil}
    CharacterManager.update(character)

    {:noreply, state}
  end

  defp log_sent_packet(opcode, packet) do
    name = Packets.opcode_to_name(:send, opcode)

    unless name in conf()[:skip_packet_logs] do
      L.debug(IO.ANSI.format([:magenta, "[SEND] #{name}: #{stringify_packet(packet)}"]))
    end
  end
end
