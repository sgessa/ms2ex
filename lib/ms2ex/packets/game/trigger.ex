defmodule Ms2ex.Packets.Trigger do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x2,
    update: 0x3,
    camera_start: 0x5,
    ui: 0x8
  }

  @ui_modes %{
    guide: 0x1,
    show_summary: 0x2,
    hide_summary: 0x3,
    start_movie: 0x4,
    skip_movie: 0x5,
    emotion_sequence: 0x7,
    emotion_loop: 0x8,
    face_emotion: 0x9
  }

  # Sent once at field load: registers every trigger object id so the client
  # can resolve later references (mesh updates, camera paths, effects).
  # Meshes already dropped by opened gates join as hidden entries.
  def load(meshes \\ [], cameras \\ [], sounds \\ []) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_int(length(meshes) + length(cameras) + length(sounds))
    |> reduce(meshes, fn mesh, packet -> put_mesh(packet, false, mesh) end)
    |> reduce(cameras, fn camera, packet -> put_camera(packet, camera) end)
    |> reduce(sounds, fn sound, packet -> put_sound(packet, sound) end)
  end

  # camera entries only register the path ids so later CameraStart/
  # update packets can reference them; they must not arrive visible — the
  # client would activate that camera view immediately and the view is
  # only restored by a script-driven camera reset
  defp put_camera(packet, camera) do
    packet
    |> put_int(camera.id)
    |> put_bool(false)
  end

  # sound entries carry their initial enabled state
  defp put_sound(packet, sound) do
    packet
    |> put_int(sound.id)
    |> put_bool(sound.visible)
  end

  # Notifies the client that a map trigger mesh changed state — e.g. a
  # barrier mesh dropping once its guard mobs are dead.
  def update_mesh(visible, mesh) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_mesh(visible, mesh)
  end

  # toggles a trigger sound object (script set_sound); the body is just
  # the id and the new state
  def update_sound(id, visible) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_int(id)
    |> put_bool(visible)
  end

  def hide_mesh(mesh), do: update_mesh(false, mesh)

  # advances the client's guide widget to the given step — e.g. the tutorial
  # ui moving on to "head to the exit" once the barrier drops
  def guide_event(event_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.guide)
    |> put_int(event_id)
  end

  # starts a scene movie on the client (cinematic intro sequences); the
  # client answers with a Trigger ui packet once it stops
  def start_movie(file_name, movie_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.start_movie)
    |> put_string(file_name)
    |> put_int(movie_id)
  end

  # echoes the client's movie-stop back so it resets its player state
  def skip_movie(movie_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.skip_movie)
    |> put_int(movie_id)
  end

  # the player loops an emote sequence for a scripted beat; loop=false
  # plays it for the duration only
  def emotion_loop(sequence_name, duration, loop) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.emotion_loop)
    |> put_bool(loop)
    |> put_int(duration)
    |> put_ustring(sequence_name)
  end

  # the player plays one or more emote sequences back to back; the client
  # resolves the names against the player model's animation table
  def emotion_sequence(sequence_names) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.emotion_sequence)
    |> put_int(length(sequence_names))
    |> reduce(sequence_names, fn sequence_name, packet ->
      put_ustring(packet, sequence_name)
    end)
  end

  # a facial expression overlay on an actor
  def face_emotion(object_id, emotion) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.face_emotion)
    |> put_int(object_id)
    |> put_string(emotion)
  end

  # the objective pointer arrow marking where the current step wants the
  # player to go
  def show_summary(entity_id, text_id, duration \\ 0) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.show_summary)
    |> put_int(entity_id)
    |> put_int(text_id)
    |> put_int(duration)
  end

  def hide_summary(entity_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.hide_summary)
    |> put_int(entity_id)
  end

  # plays a scripted camera path (trigger cameras from the map data)
  def camera_start(path_ids, return_view \\ false) do
    __MODULE__
    |> build()
    |> put_byte(@modes.camera_start)
    |> put_byte(length(path_ids))
    |> reduce(path_ids, fn path_id, packet -> put_int(packet, path_id) end)
    |> put_bool(return_view)
  end

  # trigger effects (nif attachments) share the update body with meshes up
  # to the visibility flag; the trailing bool/int are always unset
  def update_effect(visible, %{id: id}) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_int(id)
    |> put_bool(visible)
    |> put_bool(false)
    |> put_int(0)
  end

  # minimap_invisible is the mesh's own flag carried verbatim
  defp put_mesh(packet, visible, %{id: id, minimap_invisible: minimap, scale: scale}) do
    packet
    |> put_int(id)
    |> put_bool(visible)
    |> put_bool(minimap)
    |> put_int()
    |> put_ustring()
    |> put_float(scale)
  end
end
