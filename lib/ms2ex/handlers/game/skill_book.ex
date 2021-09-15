defmodule Ms2ex.GameHandlers.SkillBook do
  require Logger

  alias Ms2ex.{Characters, Net, Packets, Skills, Wallets, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {:ok, character} = World.get_character(session.character_id)
    handle_mode(mode, packet, character, session)
  end

  # Open
  defp handle_mode(0x0, _packet, character, session) do
    push(session, Packets.SkillBook.open(character))
  end

  # Save
  defp handle_mode(0x1, packet, character, session) do
    {active_tab_id, packet} = get_long(packet)
    {selected_tab_id, packet} = get_long(packet)
    {_, packet} = get_int(packet)
    {tab_count, packet} = get_int(packet)

    {_packet, character} =
      Enum.reduce(1..tab_count, {packet, character}, fn _, {packet, character} ->
        {tab_id, packet} = get_long(packet)
        {tab_name, packet} = get_ustring(packet)

        tab = Skills.get_tab(character, tab_id)
        {:ok, tab} = add_or_update_tab(tab, character, %{id: tab_id, name: tab_name})

        {skill_count, packet} = get_int(packet)
        {skills, packet} = save_skills(skill_count, tab, packet)

        {packet, update_character_skill_tab(character, tab, skills)}
      end)

    {:ok, character} = Characters.update(character, %{active_skill_tab_id: active_tab_id})
    World.update_character(character)

    push(session, Packets.SkillBook.save(character, selected_tab_id))
  end

  # Add Tab
  @add_tab_cost -990
  defp handle_mode(0x4, _packet, character, session) do
    with {:ok, wallet} <- Wallets.update(character, :merets, @add_tab_cost) do
      session
      |> push(Packets.Wallet.update(wallet, :merets))
      |> push(Packets.SkillBook.add_tab(character))
    end
  end

  defp handle_mode(_mode, _packet, _character, session), do: session

  defp add_or_update_tab(nil, character, attrs) do
    Skills.add_tab(character, attrs)
  end

  defp add_or_update_tab(tab, _character, attrs) do
    Skills.update_tab(tab, attrs)
  end

  defp update_character_skill_tab(character, tab, new_skills) do
    index = Enum.find_index(character.skill_tabs, &(&1.id == tab.id))

    # Update tab skills
    skill_tabs =
      List.update_at(character.skill_tabs, index, fn _ ->
        %{tab | skills: new_skills}
      end)

    %{character | skill_tabs: skill_tabs}
  end

  defp save_skills(skill_count, tab, packet) when skill_count > 0 do
    Enum.reduce(1..skill_count, {[], packet}, fn _, {_skills, packet} ->
      {skill_id, packet} = get_int(packet)

      {skill_level, packet} = get_int(packet)
      skill_level = max(skill_level, 0)

      skill = Skills.find_in_tab(tab, skill_id)
      {:ok, skill} = Skills.update(skill, %{level: skill_level})

      # Update skill in tab
      index = Enum.find_index(tab.skills, &(&1.skill_id == skill_id))
      skills = List.update_at(tab.skills, index, fn _ -> skill end)

      {skills, packet}
    end)
  end

  defp save_skills(_skill_count, tab, packet), do: {tab.skills, packet}
end
