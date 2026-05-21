defmodule Passeur.MCPPlug do
  @moduledoc """
  Wraps the Anubis MCP StreamableHTTP Plug with Bearer token authentication.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = Passeur.Plugs.BearerAuth.call(conn, [])

    if conn.halted do
      conn
    else
      mcp_server = Application.get_env(:passeur, :mcp_server, Passeur.MCPServer)

      opts =
        Anubis.Server.Transport.StreamableHTTP.Plug.init(
          server: mcp_server,
          force_json_responses: true
        )

      Anubis.Server.Transport.StreamableHTTP.Plug.call(conn, opts)
    end
  end
end
