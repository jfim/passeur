defmodule Passeur.Plugs.BearerAuthTest do
  use ExUnit.Case, async: false

  alias Passeur.Plugs.BearerAuth
  alias Plug.Test

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Passeur.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Passeur.Repo, {:shared, self()})
    prev = Application.get_env(:passeur, :static_bearer_tokens, [])
    on_exit(fn -> Application.put_env(:passeur, :static_bearer_tokens, prev) end)
    :ok
  end

  defp call_with_auth(header) do
    Test.conn(:post, "/mcp", "")
    |> Plug.Conn.put_req_header("authorization", header)
    |> BearerAuth.call([])
  end

  test "accepts a configured static bearer token" do
    Application.put_env(:passeur, :static_bearer_tokens, ["svc-a-secret", "svc-b-secret"])

    conn = call_with_auth("Bearer svc-b-secret")

    refute conn.halted
    assert conn.assigns.oauth_token == %{static: true}
  end

  test "rejects an unknown bearer token when no Boruta match" do
    Application.put_env(:passeur, :static_bearer_tokens, ["svc-a-secret"])

    conn = call_with_auth("Bearer nope")

    assert conn.halted
    assert conn.status == 401
  end

  test "rejects when no authorization header is present" do
    Application.put_env(:passeur, :static_bearer_tokens, ["svc-a-secret"])

    conn =
      Test.conn(:post, "/mcp", "")
      |> BearerAuth.call([])

    assert conn.halted
    assert conn.status == 401
  end

  test "static token list defaulting to empty does not crash" do
    Application.delete_env(:passeur, :static_bearer_tokens)

    conn = call_with_auth("Bearer anything")

    assert conn.halted
    assert conn.status == 401
  end
end
