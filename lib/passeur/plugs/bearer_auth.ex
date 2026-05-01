defmodule Passeur.Plugs.BearerAuth do
  @moduledoc """
  Plug that validates OAuth Bearer tokens on MCP requests.
  Returns 401 with WWW-Authenticate header if token is missing or invalid.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, :static} ->
        assign(conn, :oauth_token, %{static: true})

      {:ok, %{expires_at: expires_at} = token} ->
        if expires_at > :os.system_time(:second) do
          assign(conn, :oauth_token, token)
        else
          Logger.debug("Bearer auth failed: token expired")
          unauthorized(conn)
        end

      {:error, reason} ->
        Logger.debug("Bearer auth failed: #{reason}")
        unauthorized(conn)
    end
  end

  defp authenticate(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token_value] when token_value != "" ->
        if static_token_match?(token_value) do
          {:ok, :static}
        else
          case Boruta.Config.access_tokens().get_by(value: token_value) do
            %{} = token -> {:ok, token}
            nil -> {:error, "token not found"}
          end
        end

      [] ->
        {:error, "no authorization header"}

      _ ->
        {:error, "invalid authorization header"}
    end
  end

  defp static_token_match?(token_value) do
    :passeur
    |> Application.get_env(:static_bearer_tokens, [])
    |> Enum.any?(&Plug.Crypto.secure_compare(&1, token_value))
  end

  defp unauthorized(conn) do
    server_url = Application.get_env(:passeur, :server_url)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "www-authenticate",
      "Bearer resource_metadata=\"#{server_url}/.well-known/oauth-protected-resource\""
    )
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
