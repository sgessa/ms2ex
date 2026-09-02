defmodule Ms2ex.Packets do
  alias Ms2ex.Packets.Ops

  def name_to_opcode(:send, name) do
    case Enum.find(send_ops(), fn {_k, v} -> name == v end) do
      {opcode, _name} -> opcode
      _ -> nil
    end
  end

  def opcode_to_name(type, opcode, base \\ :hex)

  def opcode_to_name(:recv, opcode, base) do
    Map.get(recv_ops(), opcode) || inspect(opcode, base: base)
  end

  def opcode_to_name(:send, :handshake, _base), do: "HANDSHAKE"

  def opcode_to_name(:send, opcode, base) do
    Map.get(send_ops(), opcode) || inspect(opcode, base: base)
  end

  def recv_ops(), do: Ops.Recv.all_map()
  def send_ops(), do: Ops.Send.all_map()
end
