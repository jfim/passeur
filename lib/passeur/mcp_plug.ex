defmodule Passeur.MCPPlug do
  @moduledoc """
  Wraps the MCP StreamableHTTP Plug with Bearer token authentication.
  For POST requests, uses JSON responses instead of SSE routing to
  ensure compatibility with Claude Code and claude.ai.
  """

  @behaviour Plug

  import Plug.Conn

  alias Hermes.Server.Transport.StreamableHTTP

  @session_header "mcp-session-id"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = Passeur.Plugs.BearerAuth.call(conn, [])

    unless conn.halted do
      case conn.method do
        "POST" -> handle_post(conn)
        _ -> forward_to_hermes(conn)
      end
    else
      conn
    end
  end

  defp handle_post(conn) do
    transport = get_transport()

    with {:ok, body, conn} <- read_body_params(conn),
         {:ok, message} <- parse_message(body) do
      session_id = get_session_id(conn, message)
      context = build_context(conn)

      if is_notification?(message) do
        case StreamableHTTP.handle_message(transport, session_id, message, context) do
          {:ok, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(202, "{}")

          {:error, _reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(202, "{}")
        end
      else
        case StreamableHTTP.handle_message(transport, session_id, message, context) do
          {:ok, response} ->
            conn
            |> put_resp_content_type("application/json")
            |> maybe_put_session_header(session_id)
            |> send_resp(200, response)

          {:error, %Hermes.MCP.Error{} = error} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{
              jsonrpc: "2.0",
              error: %{code: error.code, message: error.message, data: error.data},
              id: message["id"]
            }))

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{
              jsonrpc: "2.0",
              error: %{code: -32603, message: "Internal error", data: %{reason: inspect(reason)}},
              id: message["id"]
            }))
        end
      end
    else
      {:error, :invalid_json} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{
          jsonrpc: "2.0",
          error: %{code: -32700, message: "Parse error"},
          id: nil
        }))
    end
  end

  defp forward_to_hermes(conn) do
    mcp_server = Application.get_env(:passeur, :mcp_server, Passeur.MCPServer)
    opts = Hermes.Server.Transport.StreamableHTTP.Plug.init(server: mcp_server)
    Hermes.Server.Transport.StreamableHTTP.Plug.call(conn, opts)
  end

  defp get_transport do
    mcp_server = Application.get_env(:passeur, :mcp_server, Passeur.MCPServer)
    Hermes.Server.Registry.transport(mcp_server, :streamable_http)
  end

  defp read_body_params(%{body_params: %Plug.Conn.Unfetched{}} = conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} -> {:ok, body, conn}
      _ -> {:error, :read_error}
    end
  end

  defp read_body_params(%{body_params: body} = conn), do: {:ok, body, conn}

  defp parse_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, message} when is_map(message) -> {:ok, message}
      {:ok, [message]} when is_map(message) -> {:ok, message}
      _ -> {:error, :invalid_json}
    end
  end

  defp parse_message(body) when is_map(body), do: {:ok, body}
  defp parse_message([message]) when is_map(message), do: {:ok, message}

  defp get_session_id(conn, message) do
    if message["method"] == "initialize" do
      "session_" <> Base.url_encode64(:crypto.strong_rand_bytes(20))
    else
      case get_req_header(conn, @session_header) do
        [id] when id != "" -> id
        _ -> "session_" <> Base.url_encode64(:crypto.strong_rand_bytes(20))
      end
    end
  end

  defp is_notification?(message), do: not Map.has_key?(message, "id")

  defp maybe_put_session_header(conn, session_id) do
    put_resp_header(conn, @session_header, session_id)
  end

  defp build_context(conn) do
    %{
      port: conn.port,
      scheme: conn.scheme,
      type: :http,
      host: conn.host,
      request_path: conn.request_path,
      assigns: conn.assigns
    }
  end
end
