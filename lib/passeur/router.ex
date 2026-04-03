defmodule Passeur.Router do
  use Plug.Router

  plug Plug.Logger
  plug :cors_headers
  plug :put_secret_key_base
  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["application/x-www-form-urlencoded", "application/json", "text/event-stream"],
    json_decoder: Jason

  plug Plug.Session,
    store: :cookie,
    key: "_passeur_session",
    signing_salt: "passeur_signing_salt",
    encryption_salt: "passeur_encryption_salt",
    same_site: "Strict",
    http_only: true

  plug :fetch_session
  plug :dispatch

  def secret_key_base do
    Application.get_env(:passeur, :secret_key_base) ||
      raise "Missing :secret_key_base in :passeur config"
  end

  defp put_secret_key_base(conn, _opts) do
    Map.put(conn, :secret_key_base, secret_key_base())
  end

  # CORS preflight
  match _ , via: :options do
    send_resp(conn, 204, "")
  end

  # Health check
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok"}))
  end

  # Login
  get "/login" do
    Passeur.LoginController.show(conn)
  end

  post "/login" do
    Passeur.LoginController.create(conn)
  end

  # OAuth 2.1 endpoints
  get "/oauth/authorize" do
    conn
    |> Passeur.Plugs.SessionAuth.call([])
    |> Passeur.AuthorizeController.authorize()
  end

  post "/oauth/token" do
    Boruta.Oauth.token(conn, Passeur.TokenController)
  end

  # Dynamic Client Registration
  post "/oauth/register" do
    Passeur.RegistrationController.register(conn)
  end

  # Well-known metadata
  get "/.well-known/oauth-authorization-server" do
    issuer = Application.get_env(:passeur, :server_url)

    metadata = %{
      issuer: issuer,
      authorization_endpoint: "#{issuer}/oauth/authorize",
      token_endpoint: "#{issuer}/oauth/token",
      registration_endpoint: "#{issuer}/oauth/register",
      revocation_endpoint: "#{issuer}/oauth/revoke",
      response_types_supported: ["code"],
      response_modes_supported: ["query"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      revocation_endpoint_auth_methods_supported: ["none"],
      scopes_supported: ["mcp:read"]
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(metadata))
  end

  get "/.well-known/oauth-protected-resource" do
    issuer = Application.get_env(:passeur, :server_url)

    metadata = %{
      resource: "#{issuer}/mcp",
      authorization_servers: [issuer],
      scopes_supported: ["mcp:read"],
      bearer_methods_supported: ["header"]
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(metadata))
  end

  # Token revocation
  post "/oauth/revoke" do
    Boruta.Oauth.revoke(conn, Passeur.RevokeController)
  end

  # MCP endpoint (protected by Bearer token)
  forward "/mcp", to: Passeur.MCPPlug

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not found"}))
  end

  defp cors_headers(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, authorization, accept, mcp-session-id")
    |> put_resp_header("access-control-expose-headers", "mcp-session-id")
    |> put_resp_header("access-control-max-age", "3600")
  end
end
