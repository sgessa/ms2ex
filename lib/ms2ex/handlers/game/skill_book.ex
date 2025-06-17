defmodule Ms2ex.GameHandlers.SkillBook do
  require Logger

  alias Ms2ex.{Managers, Context, Net, Packets, Constants}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  @load 0x0
  @save 0x1
  @rename 0x2
  @expand 0x4

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {:ok, character} = Managers.Character.lookup(session.character_id)
    handle_mode(mode, packet, character, session)
  end

  # Open
  defp handle_mode(@load, _packet, character, session) do
    push(session, Packets.SkillBook.open(character))
  end

  # Save
  defp handle_mode(@save, packet, character, session) do
    {active_tab_id, packet} = get_long(packet)
    {selected_tab_id, packet} = get_long(packet)
    {rank, packet} = get_int(packet)
    {tab_count, packet} = get_int(packet)

    _packet =
      Enum.reduce(1..tab_count, packet, fn _, packet ->
        {tab_id, packet} = get_long(packet)
        {tab_name, packet} = get_ustring(packet)

        tab = Context.Skills.get_tab(character, tab_id)
        {:ok, tab} = add_or_update_tab(character, tab, %{id: tab_id, name: tab_name})

        {skill_count, packet} = get_int(packet)
        packet = save_skills(skill_count, tab, packet)

        packet
      end)

    # TODO avoid SQL query
    character = Context.Characters.load_skills(character, force: true)
    {:ok, character} = Context.Characters.update(character, %{active_skill_tab_id: active_tab_id})
    Managers.Character.update(character)

    push(session, Packets.SkillBook.save(character, selected_tab_id, rank))
  end

  # Rename Tab
  defp handle_mode(@rename, packet, character, session) do
    {tab_id, packet} = get_long(packet)
    {new_name, _packet} = get_ustring(packet)

    tab = Context.Skills.get_tab(character, tab_id)
    {:ok, tab} = Context.Skills.update_tab(tab, %{name: new_name})

    idx = Enum.find_index(character.skill_tabs, &(&1.id == tab_id))
    tabs = List.update_at(character.skill_tabs, idx, fn _ -> tab end)

    Managers.Character.update(%{character | skill_tabs: tabs})

    push(session, Packets.SkillBook.rename(tab_id, new_name))
  end

  # Add Tab
  defp handle_mode(@expand, _packet, character, session) do
    expand_skill_tab_cost = Constants.get(:expand_skill_tab_cost)

    with {:ok, wallet} <- Context.Wallets.update(character, :merets, expand_skill_tab_cost) do
      session
      |> push(Packets.Wallet.update(wallet, :merets))
      |> push(Packets.SkillBook.add_tab(character))
    end
  end

  defp handle_mode(_mode, _packet, _character, session), do: session

  defp add_or_update_tab(character, nil, attrs) do
    Context.Skills.add_tab(character, attrs)
  end

  defp add_or_update_tab(_character, tab, attrs) do
    Context.Skills.update_tab(tab, attrs)
  end

  defp save_skills(skill_count, tab, packet) when skill_count > 0 do
    Enum.reduce(1..skill_count, packet, fn _, packet ->
      {skill_id, packet} = get_int(packet)

      {skill_level, packet} = get_int(packet)
      skill_level = max(skill_level, 0)

      skill = Context.Skills.find_in_tab(tab, skill_id)
      {:ok, _skill} = Context.Skills.update(skill, %{level: skill_level})

      packet
    end)
  end

  defp save_skills(_skill_count, _tab, packet), do: packet
end
