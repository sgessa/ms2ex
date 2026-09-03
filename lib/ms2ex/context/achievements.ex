defmodule Ms2ex.Context.Achievements do
  alias Ms2ex.Managers.Quest.Conditions
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ecto.Query, only: [from: 2]

  def all(owner_id),
    do: Repo.all(from achievement in Schema.Achievement, where: achievement.owner_id == ^owner_id)

  def get(owner_id, achievement_id), do: Repo.get(Schema.Achievement, [owner_id, achievement_id])

  def create(attrs) do
    %Schema.Achievement{}
    |> Schema.Achievement.changeset(attrs)
    |> Repo.insert()
  end

  def update(achievement, attrs) do
    achievement
    |> Schema.Achievement.changeset(attrs)
    |> Repo.update()
  end

  def progress(
        character,
        condition_type,
        count,
        target_string,
        target_long,
        code_string,
        code_long
      ) do
    Storage.Achievements.for_condition(condition_type)
    |> Enum.each(
      &progress_metadata(&1, character, count, target_string, target_long, code_string, code_long)
    )
  end

  def load(character) do
    [character.account_id, character.id]
    |> Enum.flat_map(&all/1)
    |> Enum.map(fn achievement ->
      Map.put(achievement, :metadata, Storage.Achievements.get(achievement.achievement_id))
    end)
    |> then(fn achievements ->
      Ms2ex.Net.SenderSession.push(character, Packets.Achievement.initialize())
      Ms2ex.Net.SenderSession.push(character, Packets.Achievement.load(achievements))
    end)
  end

  def toggle_favorite(character, achievement_id, favorite) do
    achievement = Enum.find_value([character.account_id, character.id], &get(&1, achievement_id))

    with %Schema.Achievement{} = achievement <- achievement,
         {:ok, updated} <- update(achievement, %{favorite: favorite}) do
      Ms2ex.Net.SenderSession.push(character, Packets.Achievement.favorite(updated))
    else
      nil -> :ok
      error -> error
    end
  end

  def claim_reward(character, achievement_id) do
    with {achievement, metadata} <- achievement_with_metadata(character, achievement_id),
         {:ok, updated} <- claim_pending_rewards(character, achievement, metadata) do
      Ms2ex.Net.SenderSession.push(
        character,
        Packets.Achievement.update(Map.put(updated, :metadata, metadata))
      )
    else
      _ -> :ok
    end
  end

  defp update_progress(character, metadata, count) do
    owner_id = if metadata.account_wide, do: character.account_id, else: character.id
    existing = get(owner_id, metadata.id)
    achievement = existing || new_achievement(owner_id, metadata)
    grade = active_grade(achievement, metadata)
    counter = achievement.counter + count
    grades = complete_grades(achievement.grades, metadata.grades, counter)
    next_grade = next_grade(metadata.grades, grades, grade)

    attrs = %{counter: counter, grades: grades, current_grade: next_grade}

    case persist(existing, achievement, attrs) do
      {:ok, updated} ->
        if updated.counter != achievement.counter do
          Packets.Achievement.update(Map.put(updated, :metadata, metadata))
          |> send_packet(character)
        end

      _ ->
        :ok
    end
  end

  defp progress_metadata(
         metadata,
         character,
         count,
         target_string,
         target_long,
         code_string,
         code_long
       ) do
    case active_condition(metadata, character) do
      nil ->
        :ok

      condition ->
        if Conditions.metadata_matches?(
             condition,
             target_string,
             target_long,
             code_string,
             code_long
           ),
           do: update_progress(character, metadata, count)
    end
  end

  defp achievement_with_metadata(character, achievement_id) do
    metadata = Storage.Achievements.get(achievement_id)

    achievement =
      [character.account_id, character.id]
      |> Enum.find_value(fn owner_id -> get(owner_id, achievement_id) end)

    if achievement && metadata, do: {achievement, metadata}, else: nil
  end

  defp deliver_reward(_character, nil), do: :ok

  defp deliver_reward(character, %{type: :item, code: item_id, value: amount, rank: rarity}) do
    item = Ms2ex.Context.Items.init(item_id, %{amount: amount, rarity: rarity})

    case Ms2ex.Context.Inventory.add_item(character, item) do
      {:ok, result} ->
        Ms2ex.Net.SenderSession.push(character, Packets.InventoryItem.add_item(result, character))
        :ok

      _ ->
        :error
    end
  end

  defp deliver_reward(character, %{type: :stat_point, value: amount}) do
    case Ms2ex.Managers.Character.call(character, {:add_stat_point, :trophy, amount}) do
      {:ok, _character} -> :ok
      _ -> :error
    end
  end

  defp deliver_reward(character, %{type: :title, code: title_id}) do
    title = Ecto.build_assoc(character, :titles, %{title_id: title_id})

    case Repo.insert(title, on_conflict: :nothing) do
      {:ok, _title} ->
        Ms2ex.Net.SenderSession.push(character, Ms2ex.Packets.UserEnv.set_titles([title_id]))
        :ok

      _ ->
        :error
    end
  end

  defp deliver_reward(_character, _reward), do: :ok

  defp claim_pending_rewards(character, achievement, metadata) do
    if achievement.reward_grade > achievement.current_grade do
      {:ok, achievement}
    else
      reward = get_in(metadata, [:grades, Integer.to_string(achievement.reward_grade), :reward])

      with :ok <- deliver_reward(character, reward),
           {:ok, updated} <- update(achievement, %{reward_grade: achievement.reward_grade + 1}) do
        claim_pending_rewards(character, updated, metadata)
      end
    end
  end

  defp active_condition(metadata, character) do
    achievement =
      get(if(metadata.account_wide, do: character.account_id, else: character.id), metadata.id)

    grade = active_grade(achievement, metadata)
    get_in(metadata, [:grades, Integer.to_string(grade), :condition])
  end

  defp new_achievement(owner_id, metadata) do
    grade = metadata.grades |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.min()

    %Schema.Achievement{
      owner_id: owner_id,
      achievement_id: metadata.id,
      current_grade: grade,
      reward_grade: grade,
      category: metadata.category,
      grades: %{}
    }
  end

  defp active_grade(nil, metadata), do: new_achievement(0, metadata).current_grade
  defp active_grade(achievement, _metadata), do: achievement.current_grade

  defp complete_grades(grades, metadata_grades, counter) do
    Enum.reduce(metadata_grades, grades, fn {grade, %{condition: %{value: value}}}, result ->
      if counter >= value,
        do: Map.put_new(result, grade, System.system_time(:second)),
        else: result
    end)
  end

  defp next_grade(metadata_grades, grades, current_grade) do
    metadata_grades
    |> Map.keys()
    |> Enum.map(&String.to_integer/1)
    |> Enum.sort()
    |> Enum.find(current_grade, &(not Map.has_key?(grades, Integer.to_string(&1))))
  end

  defp persist(nil, achievement, attrs),
    do: create(Map.merge(Map.from_struct(achievement), attrs))

  defp persist(_existing, achievement, attrs), do: update(achievement, attrs)

  defp send_packet(_packet, %{session_pid: nil}), do: :ok
  defp send_packet(packet, character), do: Ms2ex.Net.SenderSession.push(character, packet)
end
