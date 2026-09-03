defmodule Ms2exWeb.Ugc.UploadControllerTest do
  use Ms2exWeb.ConnCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>

  setup do
    dir = Path.join(System.tmp_dir!(), "ugc-test-#{System.unique_integer([:positive])}")
    config = Application.get_env(:ms2ex, Ms2ex)
    Application.put_env(:ms2ex, Ms2ex, put_in(config, [:ugc, :data_dir], dir))

    on_exit(fn ->
      File.rm_rf(dir)
      Application.put_env(:ms2ex, Ms2ex, config)
    end)

    {:ok, dir: dir}
  end

  defp character(name \\ "Tester") do
    account =
      Repo.insert!(%Schema.Account{
        username: "#{name}-#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    Repo.insert!(%Schema.Character{
      account_id: account.id,
      name: "#{name}#{System.unique_integer([:positive])}",
      awakened: false,
      discovered_maps: [],
      exp: 0,
      gender: :male,
      insignia_id: 0,
      level: 1,
      job: :beginner,
      map_id: 2_000_023,
      motto: "",
      rest_exp: 0,
      skin_color: %{},
      taxis: [],
      title_id: 0
    })
  end

  defp envelope(type, opts) do
    <<0::little-signed-32, Enums.UgcType.get_value(type)::little-signed-32,
      Keyword.get(opts, :account_id, 0)::little-signed-64,
      Keyword.get(opts, :character_id, 0)::little-signed-64,
      Keyword.get(opts, :resource_id, 0)::little-signed-64,
      Keyword.get(opts, :id, 0)::little-signed-32, 0::little-signed-32, 0::little-signed-64>> <>
      Keyword.get(opts, :file, @png)
  end

  defp post_upload(conn, body) do
    conn
    |> put_req_header("content-type", "application/octet-stream")
    |> post("/ugc/urq.aspx", body)
  end

  describe "upload envelope" do
    test "rejects an empty request", %{conn: conn} do
      assert post_upload(conn, "").status == 400
    end

    test "rejects a truncated header", %{conn: conn} do
      assert post_upload(conn, <<0, 1, 2, 3>>).status == 400
    end

    test "rejects an envelope with no payload", %{conn: conn} do
      assert post_upload(conn, envelope(:profile_avatar, file: "")).status == 400
    end

    test "rejects a payload over the size cap", %{conn: conn} do
      oversize = :binary.copy("a", 5 * 1024 * 1024 + 1)
      assert post_upload(conn, envelope(:profile_avatar, file: oversize)).status == 413
    end

    test "rejects an unsupported type", %{conn: conn} do
      character = character()
      {:ok, resource} = Context.Ugc.create(character.id, :none)

      body = envelope(:none, character_id: character.id, resource_id: resource.id)
      assert post_upload(conn, body).status == 400
    end
  end

  describe "profile avatars" do
    test "stores the picture and returns its path", %{conn: conn, dir: dir} do
      character = character()
      body = envelope(:profile_avatar, character_id: character.id)

      conn = post_upload(conn, body)

      assert conn.status == 200
      assert "0,data/profiles/avatar/" <> rest = conn.resp_body
      assert [id, file] = String.split(rest, "/")
      assert id == to_string(character.id)
      assert File.read!(Path.join([dir, "profiles", to_string(character.id), file])) == @png
    end

    test "keeps only the newest picture", %{conn: conn, dir: dir} do
      character = character()
      body = envelope(:profile_avatar, character_id: character.id)

      post_upload(conn, body)
      post_upload(conn, body)

      stored = File.ls!(Path.join([dir, "profiles", to_string(character.id)]))
      assert length(stored) == 1
    end
  end

  describe "resource ownership" do
    test "refuses to overwrite content owned by another character", %{conn: conn} do
      owner = character("Owner")
      attacker = character("Attacker")
      {:ok, resource} = Context.Ugc.create(owner.id, :item)

      body =
        envelope(:item, character_id: attacker.id, resource_id: resource.id, id: 11_050_001)

      assert post_upload(conn, body).status == 403
      assert Context.Ugc.get(resource.id).path == ""
    end

    test "refuses a type that does not match the resource", %{conn: conn} do
      character = character()
      {:ok, resource} = Context.Ugc.create(character.id, :item)

      body =
        envelope(:banner, character_id: character.id, resource_id: resource.id, id: 1)

      assert post_upload(conn, body).status == 403
    end

    test "refuses an unknown resource", %{conn: conn} do
      character = character()

      body =
        envelope(:item, character_id: character.id, resource_id: 123_456, id: 11_050_001)

      assert post_upload(conn, body).status == 404
    end

    test "stores the design and publishes its path", %{conn: conn, dir: dir} do
      character = character()
      {:ok, resource} = Context.Ugc.create(character.id, :item)

      body =
        envelope(:item,
          character_id: character.id,
          resource_id: resource.id,
          id: 11_050_001,
          file: "mesh"
        )

      conn = post_upload(conn, body)

      assert conn.resp_body == "0,item/ms2/01/11050001/#{resource.id}.m2u"
      assert Context.Ugc.get(resource.id).path == "item/ms2/01/11050001/#{resource.id}.m2u"
      assert File.exists?(Path.join([dir, "items", "11050001", "#{resource.id}.m2u"]))
    end
  end
end
