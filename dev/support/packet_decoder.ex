defmodule Ms2ex.Packets.Decoder do
  @moduledoc """
  Test/debug helper that decodes a built packet into a plain map of field
  values, instead of hand-walking hex bytes with `PacketReader`.

  The field layout comes from the packet module's `c:Ms2ex.Packets.Spec.spec/1`
  (see the behaviour for the layout format). Packet modules that carry a
  command byte also expose `c:Ms2ex.Packets.Spec.commands/0`, which the
  decoder uses to resolve the command's atom name.

  Usage in tests or iex:

      Ms2ex.Packets.Decoder.decode(bytes)
      #=> %{opcode: 38, name: "ADD_PORTAL", command: :add,
      #    fields: %{id: 2, ...}, rest: ""}
  """

  alias Ms2ex.Packets.PacketReader

  def decode(bytes) do
    {opcode, packet} = PacketReader.get_short(bytes)
    name = Ms2ex.Packets.opcode_to_name(:send, opcode)
    module = module_for(name)

    {command, fields, packet} = spec_fields(module, packet)

    %{
      opcode: opcode,
      name: name,
      command: command,
      fields: fields,
      rest: packet
    }
  end

  defp module_for("HANDSHAKE"), do: nil

  defp module_for(name) do
    case Ms2ex.Packets.name_to_opcode(:send, name) do
      nil ->
        nil

      _ ->
        module = String.to_atom("Elixir.Ms2ex.Packets." <> Macro.camelize(String.downcase(name)))
        Code.ensure_loaded(module)
        module
    end
  end

  defp spec_fields(nil, _packet), do: {nil, %{}, :no_spec}

  defp spec_fields(module, packet) do
    cond do
      function_exported?(module, :commands, 0) ->
        {byte, packet} = PacketReader.get_byte(packet)
        {fields, packet} = read_fields(packet, module.spec(byte))
        {command_name(module, byte), fields, packet}

      function_exported?(module, :spec, 1) ->
        {fields, packet} = read_fields(packet, module.spec(nil))
        {nil, fields, packet}

      true ->
        {nil, %{}, packet}
    end
  end

  defp command_name(module, byte) do
    module.commands()
    |> Enum.find_value(byte, fn {name, value} -> if value == byte, do: name end)
  end

  defp read_fields(packet, spec) do
    {acc, rest} =
      Enum.reduce(spec, {%{}, packet}, fn {name, type}, {acc, packet} ->
        {value, packet} = read_value(packet, type)

        acc =
          if match?("_" <> _, Atom.to_string(name)), do: acc, else: Map.put(acc, name, value)

        {acc, packet}
      end)

    {acc, rest}
  end

  defp read_value(packet, {:bytes, n}), do: PacketReader.get_bytes(packet, n)
  defp read_value(packet, fun) when is_function(fun, 1), do: fun.(packet)

  defp read_value(packet, type) do
    apply(PacketReader, :"get_#{type}", [packet])
  end
end
