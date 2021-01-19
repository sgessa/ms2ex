defmodule Ms2ex.Net.Router do
  require Logger

  alias Ms2ex.Packets

  def route(opcode, packet, session) do
    handler_name = get_handler(opcode)

    if handler = binary_to_atom(handler_name, session.type) do
      handler.handle(packet, session)
    else
      session
    end
  end

  defp get_handler(opcode), do: Map.get(Packets.recv_ops(), opcode) || :unknown_packet

  defp binary_to_atom(:unknown_packet, _session_type), do: false

  defp binary_to_atom(handler_name, session_type) do
    prefix = handler_module_prefix(handler_name, session_type)

    handler =
      handler_name
      |> String.downcase()
      |> Macro.camelize()

    String.to_existing_atom(prefix <> handler)
  rescue
    _ ->
      Logger.warn("UNKNOWN HANDLER FOR PACKET #{handler_name}")
      false
  end

  defp handler_module_prefix("SEND_LOG", _session_type), do: "Elixir.Ms2ex.Handlers."
  defp handler_module_prefix(_handler, :channel), do: "Elixir.Ms2ex.GameHandlers."
  defp handler_module_prefix(_handler, :login), do: "Elixir.Ms2ex.LoginHandlers."
end
