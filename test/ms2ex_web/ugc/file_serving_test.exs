defmodule Ms2exWeb.Ugc.FileServingTest do
  use Ms2exWeb.ConnCase, async: false

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>

  setup do
    dir = Path.join(System.tmp_dir!(), "ugc-serve-#{System.unique_integer([:positive])}")
    config = Application.get_env(:ms2ex, Ms2ex)
    Application.put_env(:ms2ex, Ms2ex, put_in(config, [:ugc, :data_dir], dir))

    on_exit(fn ->
      File.rm_rf(dir)
      Application.put_env(:ms2ex, Ms2ex, config)
    end)

    {:ok, dir: dir}
  end

  defp write(dir, segments, contents) do
    path = Path.join([dir | segments])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  test "serves a stored item mesh", %{conn: conn, dir: dir} do
    write(dir, ["items", "11050001", "42.m2u"], "mesh")

    conn = get(conn, "/ugc/item/ms2/01/11050001/42.m2u")

    assert conn.status == 200
    assert conn.resp_body == "mesh"
    assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
  end

  test "serves a guild banner from its nested directory", %{conn: conn, dir: dir} do
    write(dir, ["guildmark", "7", "banner", "9.png"], @png)

    conn = get(conn, "/ugc/guildmark/ms2/01/7/banner/9.png")

    assert conn.resp_body == @png
  end

  test "404s a missing file", %{conn: conn} do
    assert get(conn, "/ugc/item/ms2/01/11050001/42.m2u").status == 404
  end

  test "404s when the extension does not match the route", %{conn: conn, dir: dir} do
    write(dir, ["items", "1", "2.png"], @png)

    assert get(conn, "/ugc/item/ms2/01/1/2.png").status == 404
  end

  describe "path traversal" do
    setup %{dir: dir} do
      File.mkdir_p!(dir)
      File.write!(Path.join(Path.dirname(dir), "secret.png"), "secret")
      on_exit(fn -> File.rm_rf(Path.join(Path.dirname(dir), "secret.png")) end)
      :ok
    end

    test "rejects traversal in the file name", %{conn: conn} do
      conn = get(conn, "/ugc/itemicon/ms2/01/1/%2E%2E%2F%2E%2E%2Fsecret.png")

      assert conn.status == 404
      refute conn.resp_body == "secret"
    end

    test "rejects traversal in an id segment", %{conn: conn} do
      conn = get(conn, "/ugc/itemicon/ms2/01/%2E%2E/1.png")

      assert conn.status == 404
    end

    test "rejects a null byte in the file name", %{conn: conn} do
      assert get(conn, "/ugc/itemicon/ms2/01/1/a%00b.png").status == 404
    end

    test "rejects an absolute path", %{conn: conn} do
      assert get(conn, "/ugc/itemicon/ms2/01/1/%2Fetc%2Fpasswd.png").status == 404
    end
  end
end
