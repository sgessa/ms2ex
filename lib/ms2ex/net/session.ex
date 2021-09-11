defmodule Ms2ex.Net.Session do
  @moduledoc """
  TCP client and protocol for ms2
  """

  use GenServer

  require Logger, as: L

  @behaviour :ranch_protocol

  alias Ms2ex.Crypto.{Cipher, RecvCipher, SendCipher}
  alias Ms2ex.Packets
  alias Ms2ex.Packets.PacketReader
  alias Ms2ex.Net.Router
  alias Ms2ex.Net.SessionSender

  import Ms2ex.Net.Utils

  @conf Application.get_env(:ms2ex, Ms2ex)
  @skip_packet_logs @conf[:skip_packet_logs] || []
  @version @conf[:version] || 12
  @block_iv @conf[:initial_block_iv] || @version

  @doc """
  Starts the handler with `:proc_lib.spawn_link/3`.
  """
  def start_link(ref, transport, opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, transport, opts])
    {:ok, pid}
  end

  # genserver complaining
  def init(init_arg) do
    {:ok, init_arg}
  end

  # Client

  def push(state, packet) when is_binary(packet) and byte_size(packet) > 0 do
    if Process.alive?(state.sender_pid) do
      SessionSender.push(state.sender_pid, packet)
    end

    state
  end

  def push(state, _packet), do: state

  def push_notice(state, character, notice) do
    push(state, Packets.UserChat.bytes(:notice_alert, character, notice))
  end

  @doc """
  Initiates the handler, acknowledging the connection was accepted.
  Finally it makes the existing process into a `:gen_server` process and
  enters the `:gen_server` receive loop with `:gen_server.enter_loop/3`.
  """
  def init(ref, transport, opts) do
    {:ok, socket} = :ranch.handshake(ref)

    [state] = opts

    state = Map.put(state, :socket, socket)

    log_connected_client(state)

    # we set active: :once so we get a whole dataframe just once, do not overload the msg queue
    # sadly we can't use [packet: 4] due to _seq, so we have to buffer it correctly...
    :ok =
      transport.setopts(socket, [
        :binary,
        active: :once,
        nodelay: true,
        linger: {true, 0}
      ])

    Process.flag(:trap_exit, true)

    recv_iv = Cipher.iv_to_int(Cipher.generate_iv())
    send_iv = Cipher.iv_to_int(Cipher.generate_iv())

    recv_cipher = RecvCipher.build(@version, recv_iv, @block_iv)
    send_cipher = SendCipher.build(@version, send_iv, @block_iv)

    sender_pid = SessionSender.start_link(socket, transport, send_cipher, self())

    SessionSender.handshake(sender_pid, recv_cipher)

    state =
      Map.merge(state, %{
        transport: transport,
        yet_to_parse: <<>>,
        pid: self(),
        recv_cipher: recv_cipher,
        sender_pid: sender_pid
      })

    :gen_server.enter_loop(
      __MODULE__,
      [],
      state
    )
  end

  # Server callbacks

  def handle_info({:summon, character, map_id}, state) do
    {:noreply, Ms2ex.Field.change_field(character, state, map_id)}
  end

  def handle_info({:push, packet}, state) do
    {:noreply, push(state, packet)}
  end

  def handle_info(
        {:tcp, _, message},
        %{
          socket: socket,
          transport: transport,
          yet_to_parse: yet_to_parse
        } = state
      ) do
    state = process_packet(yet_to_parse, message, state)

    # accept another message
    :ok = transport.setopts(socket, active: :once)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    L.info(fn ->
      "Client disconnected"
    end)

    shutdown(state.socket, state.transport, state.sender_pid)

    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _, reason}, state) do
    L.info(fn ->
      "TCP error: #{inspect(reason)}"
    end)

    shutdown(state.socket, state.transport, state.sender_pid)

    {:stop, :normal, state}
  end

  def handle_info({:subscribe_friend_presence, character_id}, state) do
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "friend_presence:#{character_id}")
    {:noreply, state}
  end

  def handle_info({:unsubscribe_friend_presence, character_id}, state) do
    Phoenix.PubSub.unsubscribe(Ms2ex.PubSub, "friend_presence:#{character_id}")
    {:noreply, state}
  end

  def handle_info({:friend_presence, data}, state) do
    friend = Ms2ex.Friends.get_by_character_and_shared_id(state.character_id, data.shared_id)
    friend = Map.put(friend, :rcpt, data.character)

    {:noreply,
     state
     |> push(Packets.Friend.update(friend))
     |> push(Packets.Friend.presence_notification(friend))}
  end

  def handle_info(_data, state), do: {:noreply, state}

  defp shutdown(socket, transport, sender_pid) do
    Ms2ex.Net.SessionSender.stop(sender_pid)

    receive do
      {:EXIT, _responder_pid, :normal} -> :ok
    end

    L.warn("Closing socket!!")

    :ok = transport.close(socket)
  end

  defp process_packet(yet_to_parse, message, state) do
    case parse_packet(yet_to_parse <> message) do
      {<<>>, {:ok, packet}} ->
        state = decrypt_data(packet, state)
        %{state | yet_to_parse: <<>>}

      {not_parsed, {:ok, packet}} ->
        state = decrypt_data(packet, state)
        process_packet(<<>>, not_parsed, state)

      {not_parsed, {}} ->
        %{state | yet_to_parse: not_parsed}
    end
  end

  defp decrypt_data(packet, state) do
    {cipher, packet} = RecvCipher.decrypt(state.recv_cipher, packet)

    {opcode, packet} = PacketReader.get_short(packet)

    log_incoming_packet(opcode, packet)

    Router.route(opcode, packet, %{state | recv_cipher: cipher})
  end

  defp parse_packet(
         <<seq::little-integer-16, length::little-integer-32, packet::binary-size(length),
           rest::binary>>
       ) do
    # copying... how do we avoid it?
    {rest, {:ok, <<seq::little-integer-16, length::little-integer-32, packet::binary>>}}
  end

  defp parse_packet(unparsed) do
    {unparsed, {}}
  end

  defp log_connected_client(%{socket: socket, type: :login_server}) do
    L.info("Client #{peername(socket)} connected to Login Server")
  end

  defp log_connected_client(%{socket: socket, world_name: world, type: :world_login}) do
    L.info("Client #{peername(socket)} connected to World #{world}")
  end

  defp log_connected_client(%{channel_id: id, socket: socket, type: :channel}) do
    L.info("Client #{peername(socket)} connected to Channel #{id}")
  end

  defp log_incoming_packet(opcode, packet) do
    name = Packets.opcode_to_name(:recv, opcode)

    unless name in @skip_packet_logs do
      L.debug("[RECV] #{name}: #{stringify_packet(packet)}")
    end
  end
end
