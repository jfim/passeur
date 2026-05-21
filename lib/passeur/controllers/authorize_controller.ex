defmodule Passeur.AuthorizeController do
  @behaviour Boruta.Oauth.AuthorizeApplication

  import Plug.Conn
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner

  def authorize(conn) do
    case conn.assigns[:current_user] do
      nil ->
        redirect_to_login(conn)

      %ResourceOwner{} = resource_owner ->
        Boruta.Oauth.authorize(conn, resource_owner, __MODULE__)
    end
  end

  @impl true
  def preauthorize_success(conn, _response) do
    # Auto-approve for single-user setup
    authorize(conn)
  end

  @impl true
  def preauthorize_error(conn, %Error{} = error) do
    authorize_error(conn, error)
  end

  @impl true
  def authorize_success(conn, %AuthorizeResponse{} = response) do
    redirect_uri = AuthorizeResponse.redirect_to_url(response)

    conn
    |> put_resp_header("location", redirect_uri)
    |> send_resp(302, "")
  end

  @impl true
  def authorize_error(conn, %Error{format: format} = error) when not is_nil(format) do
    redirect_uri = Error.redirect_to_url(error)

    conn
    |> put_resp_header("location", redirect_uri)
    |> send_resp(302, "")
  end

  def authorize_error(conn, %Error{status: status, error: error, error_description: description}) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      status_code(status),
      Jason.encode!(%{error: error, error_description: description})
    )
  end

  defp redirect_to_login(conn) do
    query = URI.encode_query(conn.query_params)
    return_to = "/oauth/authorize?#{query}"

    conn
    |> put_resp_header("location", "/login?return_to=#{URI.encode_www_form(return_to)}")
    |> send_resp(302, "")
  end

  defp status_code(:bad_request), do: 400
  defp status_code(:unauthorized), do: 401
  defp status_code(:internal_server_error), do: 500
  defp status_code(status) when is_atom(status), do: Plug.Conn.Status.code(status)
end
