defmodule Ms2ex.Net.SessionSender do
  use GenServer

  require Logger, as: L

  alias Ms2ex.Crypto.SendCipher
  alias Ms2ex.Packets
  alias Ms2ex.Packets.{PacketReader, RequestVersion}

  import Ms2ex.Net.Utils

  @conf Application.get_env(:ms2ex, Ms2ex)
  @skip_packet_logs @conf[:skip_packet_logs] || []
  @version @conf[:version] || 12
  @block_iv @conf[:initial_block_iv] || @version

  def start_link(socket, transport, send_cipher, parent_pid) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [socket, transport, send_cipher, parent_pid])
    pid
  end

  # Client

  def handshake(pid, recv_cipher) do
    GenServer.cast(pid, {:handshake, recv_cipher})
  end

  def push(pid, packet) do
    GenServer.cast(pid, {:push, packet})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

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
  def handle_cast({:handshake, recv_cipher}, state) do
    %{send_cipher: send_cipher, socket: socket} = state
    packet = RequestVersion.build(@version, recv_cipher, send_cipher, @block_iv)
    {send_cipher, packet} = SendCipher.write_header(send_cipher, packet)

    log_sent_packet(:handshake, packet)
    state.transport.send(socket, packet)

    {:noreply, %{state | send_cipher: send_cipher}}
  end

  @impl true
  def handle_cast({:push, packet}, state) do
    %{send_cipher: cipher, socket: socket, transport: transport} = state

    {opcode, data} = PacketReader.get_short(packet)
    log_sent_packet(opcode, data)

    {cipher, enc_packet} = SendCipher.encrypt(cipher, packet)
    transport.send(socket, enc_packet)

    {:noreply, %{state | send_cipher: cipher}}
  end

  defp log_sent_packet(opcode, packet) do
    name = Packets.opcode_to_name(:send, opcode)

    unless name in @skip_packet_logs do
      L.debug(IO.ANSI.format([:magenta, "[SEND] #{name}: #{stringify_packet(packet)}"]))
    end
  end
end
