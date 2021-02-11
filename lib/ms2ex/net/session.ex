defmodule Ms2ex.Net.Session do
  use GenServer

  require Logger, as: L

  alias Ms2ex.Crypto.{Cipher, RecvCipher, SendCipher}
  alias Ms2ex.Packets
  alias Ms2ex.Packets.{PacketReader, RequestVersion}
  alias Ms2ex.Net.Router

  import Ms2ex.Net.Utils

  @behaviour :ranch_protocol
  @transport :ranch_tcp

  @conf Application.get_env(:ms2ex, Ms2ex)
  @skip_packet_logs @conf[:skip_packet_logs] || []
  @version @conf[:version] || 12
  @block_iv @conf[:initial_block_iv] || @version

  def start_link(ref, socket, transport, opts) do
    # We do not want the listener to go down if the session crashes
    GenServer.start(__MODULE__, {ref, socket, transport, opts}, [])
  end

  def init({_ref, socket, _transport, opts}) do
    @transport.setopts(socket, nodelay: true)

    log_connected_client(socket, opts)

    recv_iv = Cipher.iv_to_int(Cipher.generate_iv())
    send_iv = Cipher.iv_to_int(Cipher.generate_iv())

    recv_cipher = RecvCipher.build(@version, recv_iv, @block_iv)
    send_cipher = SendCipher.build(@version, send_iv, @block_iv)

    state =
      Map.merge(opts, %{
        pid: self(),
        socket: socket,
        recv_cipher: recv_cipher,
        send_cipher: send_cipher
      })

    send(self(), :send_handshake)

    pid = self()
    Task.start_link(fn -> loop_recv(socket, pid) end)

    {:ok, state}
  end

  def handle_info(:send_handshake, state) do
    %{recv_cipher: recv_cipher, send_cipher: send_cipher, socket: socket} = state
    packet = RequestVersion.build(@version, recv_cipher, send_cipher, @block_iv)
    {send_cipher, packet} = SendCipher.write_header(send_cipher, packet)

    log_sent_packet(:handshake, packet)
    @transport.send(socket, packet)

    {:noreply, %{state | send_cipher: send_cipher}}
  end

  def handle_info({:tcp, data}, %{recv_cipher: cipher} = state) do
    {cipher, packet} = RecvCipher.decrypt(cipher, data)

    {opcode, packet} = PacketReader.get_short(packet)

    log_incoming_packet(opcode, packet)

    state = Router.route(opcode, packet, %{state | recv_cipher: cipher})

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    L.info("Client disconnected")
    {:stop, :normal, state}
  end

  def handle_info({:push, packet}, state) do
    {:noreply, push(state, packet)}
  end

  def handle_info(_data, state), do: {:noreply, state}

  def push(state, packet) when is_binary(packet) and byte_size(packet) > 0 do
    %{send_cipher: cipher, socket: socket} = state

    {opcode, data} = PacketReader.get_short(packet)
    log_sent_packet(opcode, data)

    {cipher, enc_packet} = SendCipher.encrypt(cipher, packet)
    @transport.send(socket, enc_packet)

    %{state | send_cipher: cipher}
  end

  def push(_packet, state), do: state

  def push_notice(state, character, notice) do
    push(state, Packets.UserChat.bytes(:notice_alert, character, notice))
  end

  defp loop_recv(socket, pid) do
    recv_hdr(socket, pid)
    loop_recv(socket, pid)
  end

  defp recv_hdr(socket, pid) do
    with {:ok, hdr} <- :gen_tcp.recv(socket, 6),
         <<_seq::little-integer-16, length::little-integer-32>> <- hdr,
         {:ok, data} <- :gen_tcp.recv(socket, length) do
      send(pid, {:tcp, hdr <> data})
    else
      {:error, reason} ->
        send(pid, {:tcp_closed, reason})
    end
  end

  defp log_connected_client(socket, %{type: :login}) do
    L.info("Client #{peername(socket)} connected to Login Server")
  end

  defp log_connected_client(socket, %{world_name: world, type: :world_login}) do
    L.info("Client #{peername(socket)} connected to World #{world}")
  end

  defp log_connected_client(socket, %{channel_id: id, world_name: world, type: :channel}) do
    L.info("Client #{peername(socket)} connected to Channel #{id} on World #{world}")
  end

  defp log_incoming_packet(opcode, packet) do
    name = Packets.opcode_to_name(:recv, opcode)

    unless name in @skip_packet_logs do
      L.debug("[RECV] #{name}: #{stringify_packet(packet)}")
    end
  end

  defp log_sent_packet(opcode, packet) do
    name = Packets.opcode_to_name(:send, opcode)

    unless name in @skip_packet_logs do
      L.debug(IO.ANSI.format([:magenta, "[SEND] #{name}: #{stringify_packet(packet)}"]))
    end
  end
end
