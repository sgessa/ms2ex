defmodule Ms2ex.GameHandlers.SmartPush do
  @moduledoc """
  Smart Push: the paid conveniences the client offers mid-activity, such as
  extending an instrument performance or keeping a mount from throwing its
  rider. Paying grants an additional effect.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  require Logger

  # these are priced by the auto-action package the client picked rather than
  # by a flat cost on the smart push entry
  @auto_action_contents ["AutoFishing", "AutoPlayInstrument"]

  def handle(packet, session) do
    {smart_push_id, packet} = get_int(packet)

    case Storage.Tables.SmartPush.lookup(smart_push_id) do
      {:ok, %{type: :additional_effect} = metadata} ->
        additional_effect(metadata, packet, session)

      {:ok, %{type: type}} ->
        Logger.warning("Unhandled smart push type #{type} for id #{smart_push_id}")
        session

      :error ->
        Logger.warning("Unknown smart push id #{smart_push_id}")
        session
    end
  end

  defp additional_effect(metadata, packet, session) do
    {package_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         :ok <- no_required_item(metadata),
         {:ok, session, opts} <- charge(session, character, metadata, package_id) do
      Context.Field.call(character, {:add_effect_buff, metadata.value, 1, character, opts})
      session
    else
      # the reference stays silent here, leaving the player with no feedback
      {:error, currency} -> push(session, Packets.Notice.message_box(lack_code(currency)))
      _ -> session
    end
  end

  defp lack_code(:mesos), do: Enums.StringCode.get_value(:s_err_lack_meso)
  defp lack_code(_currency), do: Enums.StringCode.get_value(:s_err_lack_merat)

  # tag-based item costs need item tag metadata we don't project, so those
  # entries are refused rather than handed out for free
  defp no_required_item(%{required_item: %{tag: :none}}), do: :ok
  defp no_required_item(%{required_item: _required}), do: :error
  defp no_required_item(_metadata), do: :ok

  defp charge(session, character, %{content: content} = metadata, package_id)
       when content in @auto_action_contents do
    with {:ok, package} <- Storage.Tables.AutoActions.lookup(content, package_id),
         currency_type <- currency_type(package),
         :ok <- spend(character, currency_type, package) do
      session = push(session, Packets.SmartPush.activate_effect(currency_type, metadata.value))

      # the effect's own duration is the longest package on offer, so the
      # buff has to be cut down to what the player actually bought
      {:ok, session, duration_tick: :timer.minutes(package.duration)}
    end
  end

  defp charge(session, character, metadata, _package_id) do
    case spend_merets(character, metadata.meret_cost) do
      :ok -> {:ok, session, []}
      error -> error
    end
  end

  defp currency_type(%{meret_cost: cost}) when cost > 0, do: :meret
  defp currency_type(%{meso_cost: cost}) when cost > 0, do: :meso
  defp currency_type(_package), do: :none

  defp spend(character, :meret, %{meret_cost: cost}), do: spend_merets(character, cost)
  defp spend(character, :meso, %{meso_cost: cost}), do: spend_mesos(character, cost)
  defp spend(_character, :none, _package), do: :ok

  defp spend_merets(character, cost) do
    wallet = Context.Wallets.find(%Schema.Account{id: character.account_id})
    debit(character, :merets, wallet && wallet.merets, cost)
  end

  defp spend_mesos(character, cost) do
    wallet = Context.Wallets.find(character)
    debit(character, :mesos, wallet && wallet.mesos, cost)
  end

  defp debit(_character, _currency, _balance, cost) when cost <= 0, do: :ok

  defp debit(character, currency, balance, cost) when is_integer(balance) and balance >= cost do
    Context.Wallets.update(character, currency, -cost)
    :ok
  end

  defp debit(_character, currency, _balance, _cost), do: {:error, currency}
end
