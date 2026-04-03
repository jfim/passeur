defmodule Passeur.RevokeController do
  @behaviour Boruta.Oauth.RevokeApplication

  import Plug.Conn

  @impl true
  def revoke_success(conn) do
    send_resp(conn, 200, "")
  end

  @impl true
  def revoke_error(conn, _error) do
    # RFC 7009: invalid tokens should still return 200
    send_resp(conn, 200, "")
  end
end
