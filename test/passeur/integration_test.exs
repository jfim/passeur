defmodule Passeur.IntegrationTest do
  use ExUnit.Case, async: false

  alias Plug.{Conn, Test}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Passeur.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Passeur.Repo, {:shared, self()})
    :ok
  end

  @secret_key_base Passeur.Router.secret_key_base()

  defp call(conn) do
    conn
    |> Map.put(:secret_key_base, @secret_key_base)
    |> Passeur.Router.call(Passeur.Router.init([]))
  end

  defp get(path, prev_conn \\ nil) do
    conn = Test.conn(:get, path)
    conn = if prev_conn, do: Test.recycle_cookies(conn, prev_conn), else: conn
    call(conn)
  end

  defp post(path, body, opts \\ []) do
    prev_conn = Keyword.get(opts, :prev_conn)
    content_type = Keyword.get(opts, :content_type, "application/json")

    conn =
      Test.conn(:post, path, body)
      |> Conn.put_req_header("content-type", content_type)

    conn = if prev_conn, do: Test.recycle_cookies(conn, prev_conn), else: conn
    call(conn)
  end

  defp json_body(conn) do
    Jason.decode!(conn.resp_body)
  end

  defp location(conn) do
    conn |> Conn.get_resp_header("location") |> List.first()
  end

  defp parse_mcp_response(%Finch.Response{headers: headers, body: body}) do
    content_type = headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1)
    session_id = headers |> Enum.find(fn {k, _} -> k == "mcp-session-id" end) |> then(fn
      nil -> nil
      {_, v} -> v
    end)

    data =
      if String.starts_with?(content_type, "text/event-stream") do
        body
        |> String.split("\n")
        |> Enum.filter(&String.starts_with?(&1, "data: "))
        |> Enum.map(&String.trim_leading(&1, "data: "))
        |> List.last()
        |> Jason.decode!()
      else
        Jason.decode!(body)
      end

    {data, session_id}
  end

  describe "health check" do
    test "returns 200 OK" do
      conn = get("/health")
      assert conn.status == 200
      assert json_body(conn)["status"] == "ok"
    end
  end

  describe "well-known endpoints" do
    test "oauth-authorization-server returns valid metadata" do
      conn = get("/.well-known/oauth-authorization-server")
      assert conn.status == 200

      body = json_body(conn)
      assert body["issuer"] == "http://localhost:4002"
      assert body["authorization_endpoint"] == "http://localhost:4002/oauth/authorize"
      assert body["token_endpoint"] == "http://localhost:4002/oauth/token"
      assert body["registration_endpoint"] == "http://localhost:4002/oauth/register"
      assert body["revocation_endpoint"] == "http://localhost:4002/oauth/revoke"
      assert body["response_types_supported"] == ["code"]
      assert body["grant_types_supported"] == ["authorization_code", "refresh_token"]
      assert body["code_challenge_methods_supported"] == ["S256"]
      assert body["token_endpoint_auth_methods_supported"] == ["none"]
    end

    test "oauth-protected-resource returns valid metadata" do
      conn = get("/.well-known/oauth-protected-resource")
      assert conn.status == 200

      body = json_body(conn)
      assert body["resource"] == "http://localhost:4002/mcp"
      assert body["authorization_servers"] == ["http://localhost:4002"]
      assert body["bearer_methods_supported"] == ["header"]
    end
  end

  describe "dynamic client registration" do
    test "registers a new client" do
      body = Jason.encode!(%{
        client_name: "Test MCP Client",
        redirect_uris: ["http://localhost:3000/callback"],
        grant_types: ["authorization_code"],
        response_types: ["code"],
        token_endpoint_auth_method: "none"
      })

      conn = post("/oauth/register", body)
      assert conn.status == 201

      response = json_body(conn)
      assert response["client_id"]
      assert response["client_name"] == "Test MCP Client"
      assert response["redirect_uris"] == ["http://localhost:3000/callback"]
      assert response["token_endpoint_auth_method"] == "none"
      assert response["client_id_issued_at"]
      assert response["client_secret_expires_at"] == 0
    end
  end

  describe "login flow" do
    test "GET /login renders login form" do
      conn = get("/login")
      assert conn.status == 200
      assert conn.resp_body =~ "Login"
      assert conn.resp_body =~ "<form"
    end

    test "POST /login with valid credentials sets session" do
      body = URI.encode_query(%{
        username: "admin",
        password: "test_password",
        return_to: "/health"
      })

      conn = post("/login", body, content_type: "application/x-www-form-urlencoded")
      assert conn.status == 302
      assert location(conn) == "/health"
    end

    test "POST /login with invalid credentials returns 401" do
      body = URI.encode_query(%{
        username: "admin",
        password: "wrong_password",
        return_to: "/"
      })

      conn = post("/login", body, content_type: "application/x-www-form-urlencoded")
      assert conn.status == 401
      assert conn.resp_body =~ "Login Failed"
    end
  end

  describe "OAuth 2.1 authorization code flow with PKCE" do
    setup do
      # Register a client via DCR
      register_body = Jason.encode!(%{
        client_name: "Integration Test Client",
        redirect_uris: ["http://localhost:3000/callback"],
        grant_types: ["authorization_code"],
        response_types: ["code"],
        token_endpoint_auth_method: "none"
      })

      conn = post("/oauth/register", register_body)
      client = json_body(conn)

      # Generate PKCE challenge
      code_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      code_challenge = Base.url_encode64(:crypto.hash(:sha256, code_verifier), padding: false)

      %{
        client_id: client["client_id"],
        code_verifier: code_verifier,
        code_challenge: code_challenge
      }
    end

    test "authorize without session redirects to login", %{client_id: client_id, code_challenge: code_challenge} do
      query = URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: "http://localhost:3000/callback",
        scope: "mcp:read",
        state: "test_state",
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      })

      conn = get("/oauth/authorize?#{query}")
      assert conn.status == 302
      assert location(conn) =~ "/login"
    end

    test "full flow: login -> authorize -> token exchange", %{
      client_id: client_id,
      code_verifier: code_verifier,
      code_challenge: code_challenge
    } do
      # Step 1: Login
      login_body = URI.encode_query(%{
        username: "admin",
        password: "test_password",
        return_to: "/"
      })

      login_conn = post("/login", login_body, content_type: "application/x-www-form-urlencoded")
      assert login_conn.status == 302

      # Step 2: Authorize with session from login
      authorize_query = URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: "http://localhost:3000/callback",
        scope: "mcp:read",
        state: "test_state",
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      })

      auth_conn = get("/oauth/authorize?#{authorize_query}", login_conn)
      assert auth_conn.status == 302

      redirect_uri = location(auth_conn)
      assert redirect_uri =~ "http://localhost:3000/callback"

      # Extract authorization code from redirect
      %URI{query: redirect_query} = URI.parse(redirect_uri)
      redirect_params = URI.decode_query(redirect_query)
      assert redirect_params["code"]
      assert redirect_params["state"] == "test_state"

      code = redirect_params["code"]

      # Step 3: Exchange code for token
      token_body = URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "http://localhost:3000/callback",
        client_id: client_id,
        code_verifier: code_verifier
      })

      token_conn = post("/oauth/token", token_body, content_type: "application/x-www-form-urlencoded")
      assert token_conn.status == 200

      token_response = json_body(token_conn)
      assert token_response["access_token"]
      assert token_response["token_type"] == "bearer"
      assert token_response["expires_in"]
    end
  end

  describe "MCP endpoint" do
    test "returns 401 without bearer token" do
      conn =
        Test.conn(:post, "/mcp", Jason.encode!(%{jsonrpc: "2.0", method: "initialize", id: 1}))
        |> Conn.put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 401
      assert Conn.get_resp_header(conn, "www-authenticate") |> List.first() =~ "resource_metadata"
    end

    test "full flow: DCR -> login -> authorize -> token -> MCP tool call" do
      # Steps 1-4: Get an access token via OAuth flow (using Plug.Test)
      reg_conn = post("/oauth/register", Jason.encode!(%{
        client_name: "MCP Test Client",
        redirect_uris: ["http://localhost:3000/callback"]
      }))
      assert reg_conn.status == 201
      client = json_body(reg_conn)

      login_conn = post("/login",
        URI.encode_query(%{username: "admin", password: "test_password", return_to: "/"}),
        content_type: "application/x-www-form-urlencoded")
      assert login_conn.status == 302

      code_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      code_challenge = Base.url_encode64(:crypto.hash(:sha256, code_verifier), padding: false)

      auth_conn = get("/oauth/authorize?" <> URI.encode_query(%{
        response_type: "code", client_id: client["client_id"],
        redirect_uri: "http://localhost:3000/callback", scope: "mcp:read",
        state: "mcp_test", code_challenge: code_challenge, code_challenge_method: "S256"
      }), login_conn)
      assert auth_conn.status == 302

      %{"code" => code} = auth_conn |> location() |> URI.parse() |> Map.get(:query) |> URI.decode_query()

      token_conn = post("/oauth/token",
        URI.encode_query(%{grant_type: "authorization_code", code: code,
          redirect_uri: "http://localhost:3000/callback",
          client_id: client["client_id"], code_verifier: code_verifier}),
        content_type: "application/x-www-form-urlencoded")
      assert token_conn.status == 200
      %{"access_token" => access_token} = json_body(token_conn)

      # Steps 5-7: MCP requests via real HTTP (SSE streaming needs a real connection)
      base_url = "http://localhost:4002"
      headers = [
        {"content-type", "application/json"},
        {"accept", "application/json, text/event-stream"},
        {"authorization", "Bearer #{access_token}"}
      ]

      # Step 5: Initialize
      init_body = Jason.encode!(%{
        jsonrpc: "2.0", id: 1, method: "initialize",
        params: %{protocolVersion: "2025-03-26", capabilities: %{},
          clientInfo: %{name: "test-client", version: "1.0.0"}}
      })

      {:ok, init_resp} = Finch.build(:post, "#{base_url}/mcp", headers, init_body)
        |> Finch.request(OpenIDHttpClient)

      assert init_resp.status == 200

      {init_response, session_id} = parse_mcp_response(init_resp)
      assert init_response["result"]["serverInfo"]["name"] == "Passeur"
      assert init_response["result"]["capabilities"]["tools"]
      assert session_id

      # Step 6: Send initialized notification
      notif_body = Jason.encode!(%{jsonrpc: "2.0", method: "notifications/initialized"})
      notif_headers = headers ++ [{"mcp-session-id", session_id}]

      {:ok, notif_resp} = Finch.build(:post, "#{base_url}/mcp", notif_headers, notif_body)
        |> Finch.request(OpenIDHttpClient)

      assert notif_resp.status in [200, 202]

      # Step 7: Call the hello tool
      tool_body = Jason.encode!(%{
        jsonrpc: "2.0", id: 2, method: "tools/call",
        params: %{name: "hello", arguments: %{name: "World"}}
      })

      {:ok, tool_resp} = Finch.build(:post, "#{base_url}/mcp", notif_headers, tool_body)
        |> Finch.request(OpenIDHttpClient)

      assert tool_resp.status == 200

      {tool_response, _} = parse_mcp_response(tool_resp)
      assert tool_response["result"]
      content = List.first(tool_response["result"]["content"])
      assert content["type"] == "text"
      assert content["text"] =~ "Hello, World!"
    end
  end

  describe "CORS" do
    test "OPTIONS returns CORS headers" do
      conn =
        Test.conn(:options, "/oauth/token")
        |> call()

      assert conn.status == 204
      assert Conn.get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert Conn.get_resp_header(conn, "access-control-allow-methods") |> List.first() =~ "POST"
    end

    test "regular requests include CORS headers" do
      conn = get("/health")
      assert Conn.get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end
end
