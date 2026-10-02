defmodule Ms2ex.GameHandlers.RequestItemStorage do
  @moduledoc """
  Bank storage requests: deposit, withdraw, move, mesos, expansion, sort,
  delete. The load request opens the storage (starting its process), the
  close request stops it.
  """

  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @deposit 0x0
  @withdraw 0x1
  @move 0x2
  @mesos 0x3
  @expand 0x6
  @sort 0x8
  @delete 0xA
  @load 0xC
  @close 0xF

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id) do
      dispatch(character, command, packet)
    end

    :ok
  end

  defp dispatch(character, @load, _packet) do
    :ok = Managers.Storage.start(character)
    Managers.Storage.load(character)
  end

  defp dispatch(character, @close, _packet), do: Managers.Storage.close(character)

  defp dispatch(character, command, packet) when command in [@deposit, @withdraw, @move] do
    {_zero, packet} = get_long(packet)
    {uid, packet} = get_long(packet)

    case command do
      @deposit ->
        {slot, packet} = get_short(packet)
        {amount, _packet} = get_int(packet)
        Managers.Storage.deposit(character, uid, slot, amount)

      @withdraw ->
        {slot, packet} = get_short(packet)
        {amount, _packet} = get_int(packet)
        Managers.Storage.withdraw(character, uid, slot, amount)

      @move ->
        {dst_slot, _packet} = get_short(packet)
        Managers.Storage.move(character, uid, dst_slot)
    end
  end

  # delete carries no leading zero field
  defp dispatch(character, @delete, packet) do
    {uid, _packet} = get_long(packet)
    Managers.Storage.delete(character, uid)
  end

  defp dispatch(character, command, packet) when command in [@mesos, @expand, @sort] do
    case command do
      @mesos ->
        {_zero, packet} = get_long(packet)
        {deposit?, packet} = get_bool(packet)
        {amount, _packet} = get_long(packet)

        if deposit? do
          Managers.Storage.deposit_mesos(character, amount)
        else
          Managers.Storage.withdraw_mesos(character, amount)
        end

      @expand ->
        Managers.Storage.expand(character)

      @sort ->
        Managers.Storage.sort(character)
    end
  end

  defp dispatch(_character, _command, _packet), do: :ok
end
