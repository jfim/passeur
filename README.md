# Passeur

Self-hosted Elixir MCP server framework with OAuth 2.1 and Dynamic Client Registration (DCR). Build MCP servers that work with claude.ai, Claude Desktop, and Claude Code.

## Features

- **OAuth 2.1** authorization server with PKCE support (via [boruta](https://hex.pm/packages/boruta))
- **Dynamic Client Registration** (RFC 7591) for automatic client onboarding
- **MCP Streamable HTTP** transport (via [hermes_mcp](https://hex.pm/packages/hermes_mcp))
- **Single-user admin auth** with Argon2 password hashing
- **Well-known metadata** endpoints (RFC 8414, RFC 9728)
- **Bearer token protection** for MCP endpoints
- **CORS support** for cross-origin MCP clients
- **Ecto/Postgres** for OAuth client and token storage

## Requirements

- Postgres for OAuth DCR and token storage.
- External SSL termination through nginx, Caddy, Cloudflare Tunnel, etc.
- Docker if you want to deploy this as a container

## Quick Start

1. Create a new Elixir project:

```bash
mix new my_mcp_server --sup
```

2. Add passeur as a dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:passeur, path: "../passeur"}  # or from hex when published
  ]
end
```

3. Define your MCP server with tools:

```elixir
defmodule MyServer.MCPServer do
  use Hermes.Server,
    name: "MyServer",
    version: "0.1.0",
    capabilities: [:tools]

  component MyServer.Tools.MyTool

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
```

4. Define a tool:

```elixir
defmodule MyServer.Tools.MyTool do
  @moduledoc "Description of what this tool does"

  use Hermes.Server.Component, type: :tool

  schema do
    field :input, {:required, :string}, description: "Input parameter"
  end

  @impl true
  def execute(%{input: input}, frame) do
    {:reply,
     Hermes.Server.Response.tool()
     |> Hermes.Server.Response.text("Result: #{input}"),
     frame}
  end
end
```

5. Configure passeur in `config/config.exs`:

```elixir
config :passeur,
  ecto_repos: [Passeur.Repo],
  mcp_server: MyServer.MCPServer

config :boruta, Boruta.Oauth,
  repo: Passeur.Repo,
  contexts: [
    resource_owners: Passeur.ResourceOwners
  ]
```

6. Configure environment in `config/dev.exs`:

```elixir
config :passeur,
  port: 4000,
  admin_username: "admin",
  admin_password_hash: "$argon2id$...",  # generate with: mix passeur.hash_password
  secret_key_base: "change_me_...",
  server_url: "https://your-server.example.com"

config :passeur, Passeur.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_mcp_server_dev"

config :boruta, Boruta.Oauth,
  issuer: "https://your-server.example.com"
```

7. Set up the database:

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix passeur.hash_password  # generate admin password hash
```

8. Run the server:

```bash
mix run --no-halt
```

## Production Deployment

### HTTPS Requirement

OAuth 2.1 requires HTTPS. Passeur serves plain HTTP and expects a reverse proxy to handle SSL termination. Options include:

- **Nginx Proxy Manager** — web UI for managing SSL certificates and reverse proxies
- **Cloudflare Tunnel** — expose your server via Cloudflare without opening ports
- **nginx/caddy** — traditional reverse proxy with Let's Encrypt

Set `SERVER_URL` to your public HTTPS URL (e.g. `https://mcp.example.com`). The reverse proxy should forward traffic to passeur's HTTP port.

**Note:** If using Cloudflare Access, you must create a bypass policy for your MCP server domain. Cloudflare Access intercepts 401 responses and breaks the OAuth discovery flow.

### Environment Variables

All configuration is read from environment variables in `config/runtime.exs`:

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | Postgres connection URL |
| `SECRET_KEY_BASE` | Yes | 64+ character random string |
| `ADMIN_USERNAME` | Yes | Admin login username |
| `ADMIN_PASSWORD_HASH` | Yes | Argon2 hash (from `mix passeur.hash_password`) |
| `SERVER_URL` | Yes | Public URL (e.g. `https://mcp.example.com`) |
| `PORT` | No | HTTP port (default: 4000) |
| `POOL_SIZE` | No | DB pool size (default: 10) |

## Composing Multiple MCP Servers

Since each MCP server is a module implementing `Hermes.Server`, you can compose tools from multiple packages:

```elixir
defmodule MyServer.MCPServer do
  use Hermes.Server,
    name: "MyServer",
    version: "0.1.0",
    capabilities: [:tools]

  # Your own tools
  component MyServer.Tools.MyTool

  # Tools from other packages
  component SomePackage.Tools.OtherTool

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
```

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/mcp` | POST/GET/DELETE | MCP streamable HTTP endpoint |
| `/oauth/authorize` | GET | OAuth authorization |
| `/oauth/token` | POST | Token exchange |
| `/oauth/register` | POST | Dynamic Client Registration |
| `/oauth/revoke` | POST | Token revocation |
| `/login` | GET/POST | Admin login |
| `/.well-known/oauth-authorization-server` | GET | OAuth metadata (RFC 8414) |
| `/.well-known/oauth-protected-resource` | GET | Resource metadata (RFC 9728) |

## License

MIT
