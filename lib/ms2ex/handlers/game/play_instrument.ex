defmodule Ms2ex.GameHandlers.PlayInstrument do
  @moduledoc """
  Instrument performances: freestyle improvising, playing music scores and
  reading a composed score's notes.

  The instrument itself is a field object owned by the performer, so nearby
  players hear the notes. Scores carry a limited number of plays, tracked on
  the item so it survives relogs.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types
  alias Ms2ex.Types.FieldInstrument

  import Ms2ex.Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Start Improvise
  defp handle_mode(0x0, packet, session) do
    {item_uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         :error <- Context.Field.lookup_instrument(character),
         {:ok, item} <- get_instrument(character, item_uid),
         {:ok, instrument} <- FieldInstrument.from_item(character, item, improvising?: true),
         {:ok, instrument} <- Context.Field.add_instrument(character, instrument) do
      Context.Field.broadcast(character, Packets.PlayInstrument.start_improvise(instrument))
    else
      _ -> :ok
    end
  end

  # Improvise: a single midi note, relayed as sent by the client
  defp handle_mode(0x1, packet, session) do
    {note, _packet} = get_bytes(packet, 4)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, %{improvising?: true} = instrument} <- Context.Field.lookup_instrument(character) do
      Context.Field.broadcast_from(
        character,
        Packets.PlayInstrument.improvise(instrument, note),
        self()
      )
    else
      _ -> :ok
    end
  end

  # Stop Improvise
  defp handle_mode(0x2, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, %{improvising?: true}} <- Context.Field.lookup_instrument(character),
         {:ok, instrument} <- Context.Field.remove_instrument(character) do
      Context.Field.broadcast(character, Packets.PlayInstrument.stop_improvise(instrument))
    else
      _ -> :ok
    end
  end

  # Start Score
  defp handle_mode(0x3, packet, session) do
    {item_uid, packet} = get_long(packet)
    {score_uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, score} <- start_score(character, item_uid, score_uid, []) do
      Managers.Quest.update_conditions(
        character.id,
        :music_play_score,
        1,
        "",
        character.map_id,
        "",
        score.item_id
      )
    end

    session
  end

  # Stop Score
  defp handle_mode(0x4, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, instrument} <- Context.Field.remove_instrument(character) do
      elapsed = max(Ms2ex.sync_ticks() - instrument.start_tick, 0)
      seconds = div(elapsed, 1000)

      award_music_mastery(character, instrument, elapsed)

      Managers.Quest.update_conditions(
        character.id,
        :music_play_instrument_time,
        seconds,
        "",
        character.map_id,
        "",
        instrument.metadata.id
      )

      if instrument.ensemble? do
        Managers.Quest.update_conditions(
          character.id,
          :play_ensenble_time,
          seconds,
          "",
          character.map_id
        )
      end

      Context.Field.broadcast(character, Packets.PlayInstrument.stop_score(instrument))
    else
      _ -> :ok
    end
  end

  # Join Ensemble: every member queues up, then the leader starts them all on
  # a shared tick so the parts stay in sync
  defp handle_mode(0x5, packet, session) do
    {item_uid, packet} = get_long(packet)
    {score_uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         :error <- Context.Field.lookup_instrument(character),
         {:ok, _item} <- get_instrument(character, item_uid),
         {:ok, _score} <- get_score(character, score_uid),
         {:ok, party} <- PartyServer.lookup(character.party_id) do
      Managers.Character.call(character.id, {:join_ensemble, item_uid, score_uid})

      if Types.Party.leader?(party, character), do: start_ensemble(party)
    end

    session
  end

  # Leave Ensemble
  defp handle_mode(0x6, _packet, session) do
    Managers.Character.call(session.character_id, :leave_ensemble)
    push(session, Packets.PlayInstrument.leave_ensemble())
  end

  # Compose Score: a blank score can only be written once
  defp handle_mode(0x8, packet, session) do
    {score_uid, packet} = get_long(packet)
    {length, packet} = get_int(packet)
    {instrument, packet} = get_int(packet)
    {title, packet} = get_ustring(packet)
    {mml, _packet} = get_string(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, score} <- get_blank_score(character, score_uid),
         true <- valid_mml?(score, mml),
         music <- %{
           length: length,
           instrument: instrument,
           title: title,
           author: character.name,
           author_id: character.account_id,
           locked?: false,
           mml: mml
         },
         data <- Map.put(score.data || %{}, :music, music),
         {:ok, score} <- Managers.Inventory.update_item(score, %{data: data}) do
      score = Context.Items.load_metadata(score)
      push(session, Packets.PlayInstrument.compose_score(score, character))
    else
      _ -> :ok
    end
  end

  # View Score
  defp handle_mode(0xA, packet, session) do
    {score_uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         %Schema.Item{data: %{music: %{mml: mml, author_id: author_id}}}
         when author_id != 0 <- Managers.Inventory.get(character, score_uid) do
      push(session, Packets.PlayInstrument.view_score(score_uid, mml))
    else
      _ -> :ok
    end
  end

  # Start Perform
  defp handle_mode(0xB, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.start_performance(character)
    end
  end

  # End Perform
  defp handle_mode(0xC, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.end_performance(character)
    end
  end

  # Enter/Exit Stage
  defp handle_mode(0xD, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.toggle_stage(character)
    end
  end

  # Fireworks
  defp handle_mode(0xE, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         true <- Context.Field.performance_stage?(character) do
      push(session, Packets.PlayInstrument.fireworks(character.object_id))
    else
      _ -> :ok
    end
  end

  defp handle_mode(_mode, _packet, session), do: session

  # mastery scales with how long the score played, capped by the score's
  # own maximum; the performance exp table is picked by the resulting grade
  defp award_music_mastery(character, %{score: %{} = score} = instrument, elapsed) do
    mastery = min(div(elapsed * score.mastery_value, 1000), score.mastery_value_max)
    category = Map.get(instrument.metadata || %{}, :category, 0)

    character = Context.Mastery.add(character, :music, mastery, instrument_category: category)

    exp_type =
      case Context.Mastery.grade(character, :music) do
        2 -> :music_mastery2
        3 -> :music_mastery3
        4 -> :music_mastery4
        _ -> :music_mastery1
      end

    # 500ms is dropped to account for the client/server delay; the modifier
    # counts the 500ms ticks that passed
    modifier = (elapsed - 500) / 500

    if modifier > 0 do
      exp = Ms2ex.Storage.Tables.ExpTable.typed_exp(exp_type, character.level)
      Managers.Character.cast(character, {:earn_exp, trunc(exp * modifier)})
    end
  end

  defp award_music_mastery(_character, _instrument, _elapsed), do: :ok

  defp start_score(character, item_uid, score_uid, opts) do
    with :error <- Context.Field.lookup_instrument(character),
         {:ok, item} <- get_instrument(character, item_uid),
         {:ok, score} <- get_score(character, score_uid),
         {:ok, instrument} <- FieldInstrument.from_item(character, item, opts),
         {:ok, score, remaining} <- consume_use(score),
         {:ok, instrument} <- Context.Field.add_instrument(character, mastery(instrument, score)) do
      Context.Field.broadcast(character, Packets.PlayInstrument.start_score(instrument, score))
      push(character, Packets.PlayInstrument.remaining_uses(score.id, remaining))
      {:ok, score}
    else
      _ -> :error
    end
  end

  # only the two mastery numbers of the score are kept on the field object,
  # not its metadata document
  defp mastery(instrument, score) do
    music = get_in(score.metadata, [:music]) || %{}

    %{
      instrument
      | score: %{
          mastery_value: Map.get(music, :mastery_value, 1),
          mastery_value_max: Map.get(music, :mastery_value_max, 1)
        }
    }
  end

  # every ready member starts on the leader's tick, otherwise the parts drift
  defp start_ensemble(party) do
    start_tick = Ms2ex.sync_ticks()

    case Managers.Character.call(party.leader_id, :lookup) do
      {:ok, leader} ->
        Enum.each(party.members, &start_ensemble_member(&1.id, leader, start_tick))

      _ ->
        :ok
    end
  end

  defp start_ensemble_member(character_id, leader, start_tick) do
    with {:ok, character} <- Managers.Character.call(character_id, :lookup),
         true <- same_field?(character, leader),
         %{instrument_uid: item_uid, score_uid: score_uid} <-
           Managers.Character.call(character_id, :take_ensemble),
         {:ok, _score} <-
           start_score(character, item_uid, score_uid, ensemble?: true, start_tick: start_tick) do
      Managers.Quest.update_conditions(character.id, :music_play_ensemble)

      Managers.Quest.update_conditions(
        character.id,
        :music_play_ensemble_in,
        1,
        "",
        character.map_id,
        "",
        character.map_id
      )
    else
      _ -> :ok
    end
  end

  defp same_field?(character, leader) do
    character.map_id == leader.map_id and character.channel_id == leader.channel_id
  end

  defp get_instrument(character, item_uid) do
    case Managers.Inventory.get(character, item_uid) do
      %Schema.Item{inventory_tab: :fishing_music} = item ->
        {:ok, Context.Items.load_metadata(item)}

      _ ->
        :error
    end
  end

  defp get_score(character, score_uid) do
    with %Schema.Item{inventory_tab: :fishing_music} = score <-
           Managers.Inventory.get(character, score_uid),
         %{metadata: %{music: %{}}} = score <- Context.Items.load_metadata(score),
         true <- Context.Items.remaining_uses(score) > 0 do
      {:ok, score}
    else
      _ -> :error
    end
  end

  defp get_blank_score(character, score_uid) do
    with %Schema.Item{inventory_tab: :fishing_music} = score <-
           Managers.Inventory.get(character, score_uid),
         %{metadata: %{music: %{is_custom_note: true}}} = score <-
           Context.Items.load_metadata(score),
         nil <- get_in(score.data || %{}, [:music]) do
      {:ok, score}
    else
      _ -> :error
    end
  end

  defp valid_mml?(%Schema.Item{metadata: %{music: %{note_length_max: max}}}, mml)
       when is_integer(max) and max > 0,
       do: byte_size(mml) <= max

  defp valid_mml?(_score, _mml), do: true

  defp consume_use(score) do
    remaining = Context.Items.remaining_uses(score) - 1
    data = Map.put(score.data || %{}, :remaining_uses, remaining)

    case Managers.Inventory.update_item(score, %{data: data}) do
      {:ok, score} -> {:ok, score, remaining}
      _ -> :error
    end
  end
end
