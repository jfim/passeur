defmodule Passeur.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Set boruta defaults if not already configured
    boruta_config = Application.get_env(:boruta, Boruta.Oauth, [])
    boruta_config = Keyword.put_new(boruta_config, :repo, Passeur.Repo)
    boruta_contexts = Keyword.get(boruta_config, :contexts, [])
    boruta_contexts = Keyword.put_new(boruta_contexts, :resource_owners, Passeur.ResourceOwners)
    boruta_config = Keyword.put(boruta_config, :contexts, boruta_contexts)

    # Raise the per-token max TTLs to 1 year so dynamically-registered
    # public clients (claude.ai, Claude Desktop) don't fall off after
    # Boruta's default 24h/30d caps.
    one_year = 60 * 60 * 24 * 365
    existing_max_ttl = Keyword.get(boruta_config, :max_ttl, [])

    max_ttl =
      existing_max_ttl
      |> Keyword.put_new(:access_token, one_year)
      |> Keyword.put_new(:refresh_token, one_year)

    boruta_config = Keyword.put(boruta_config, :max_ttl, max_ttl)
    Application.put_env(:boruta, Boruta.Oauth, boruta_config)

    load_static_bearer_tokens()

    port = Application.get_env(:passeur, :port, 4000)
    mcp_server = Application.get_env(:passeur, :mcp_server, Passeur.MCPServer)

    children = [
      Passeur.Repo,
      {
        mcp_server,
        # Tools like passeur_fetch can sit on a passe-partout network-idle wait
        # for up to ~30s plus surrounding I/O — give them headroom over Anubis'
        # 30s default before the MCP request is considered timed out.
        transport: {:streamable_http, start: true}, request_timeout: 90_000
      },
      {Bandit,
       plug: Passeur.Router, port: port, thousand_island_options: [read_timeout: :infinity]}
    ]

    opts = [strategy: :one_for_one, name: Passeur.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_static_bearer_tokens do
    if Application.get_env(:passeur, :static_bearer_tokens) == nil do
      tokens =
        case System.get_env("PASSEUR_STATIC_BEARER_TOKENS") do
          nil ->
            []

          "" ->
            []

          raw ->
            raw
            |> String.split(",", trim: true)
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
        end

      Application.put_env(:passeur, :static_bearer_tokens, tokens)
    end
  end
end
