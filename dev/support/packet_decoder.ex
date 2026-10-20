defmodule Ms2ex.Packets.Decoder do
  @moduledoc """
  Test/debug helper that decodes a built packet into a plain map of field
  values, instead of hand-walking hex bytes with `PacketReader`.

  Works for both server-built packets (layout from the builder module) and
  client-sent packets (layout from the handler module). In both cases the
  module adopts `Ms2ex.Packets.Spec` (see the behaviour for the layout
  format). Packets that carry a command byte also expose
  `c:Ms2ex.Packets.Spec.commands/0`, which the decoder uses to resolve the
  command's atom name.

  Usage in tests or iex:

      Ms2ex.Packets.Decoder.decode(:send, bytes)
      #=> %{opcode: 38, direction: :send, name: "ADD_PORTAL", command: :add,
      #    fields: %{id: 2, ...}, rest: ""}

      Ms2ex.Packets.Decoder.decode_hex(:recv, "11 00 00 00 00 00 05 ...")
  """

  alias Ms2ex.Packets.PacketReader

  @doc """
  Decodes packet bytes of the given direction (`:send` for server-built
  packets, `:recv` for client-sent ones). The direction determines which
  opcode table and which module type provides the layout, so both sides of
  a shared opcode resolve unambiguously.
  """
  def decode(direction, bytes) when direction in [:send, :recv] do
    {opcode, packet} = PacketReader.get_short(bytes)
    name = Ms2ex.Packets.opcode_to_name(direction, opcode)
    module = spec_module(name, direction)

    {command, fields, packet} = spec_fields(module, packet)

    %{
      opcode: opcode,
      direction: direction,
      name: name,
      command: command,
      fields: fields,
      rest: packet
    }
  end

  def decode_hex(direction, hex) do
    bytes =
      hex
      |> String.replace(~r/[^0-9a-fA-F]/, "")
      |> Base.decode16!(case: :mixed)

    decode(direction, bytes)
  end

  defp spec_module(name, direction) do
    prefixes =
      if direction == :send do
        ["Elixir.Ms2ex.Packets."]
      else
        [
          "Elixir.Ms2ex.Handlers.",
          "Elixir.Ms2ex.GameHandlers.",
          "Elixir.Ms2ex.LoginHandlers."
        ]
      end

    prefixes
    |> Enum.map(&(&1 <> Macro.camelize(String.downcase(name))))
    |> Enum.map(&load_module/1)
    |> Enum.find(&function_exported?(&1, :spec, 1))
  end

  defp load_module(nil), do: nil

  defp load_module(name) do
    module = String.to_atom(name)
    Code.ensure_loaded(module)
    module
  end

  defp spec_fields(nil, packet), do: {nil, %{}, packet}

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
