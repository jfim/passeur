defmodule Passeur.LoginController do
  import Plug.Conn

  def show(conn) do
    return_to = conn.query_params["return_to"] || "/"

    html = """
    <!DOCTYPE html>
    <html>
    <head><title>Login - Passeur</title></head>
    <body>
      <h1>Login</h1>
      <form method="POST" action="/login">
        <input type="hidden" name="return_to" value="#{html_escape(return_to)}" />
        <label>Username: <input type="text" name="username" required /></label><br/>
        <label>Password: <input type="password" name="password" required /></label><br/>
        <button type="submit">Login</button>
      </form>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def create(conn) do
    %{"username" => username, "password" => password} = conn.body_params
    return_to = conn.body_params["return_to"] || "/"

    admin_username = Application.get_env(:passeur, :admin_username)
    admin_password_hash = Application.get_env(:passeur, :admin_password_hash)

    if username == admin_username && Argon2.verify_pass(password, admin_password_hash) do
      conn
      |> put_session(:user_sub, "admin")
      |> put_resp_header("location", return_to)
      |> send_resp(302, "")
    else
      Argon2.no_user_verify()

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(401, """
      <!DOCTYPE html>
      <html>
      <head><title>Login - Passeur</title></head>
      <body>
        <h1>Login Failed</h1>
        <p>Invalid credentials.</p>
        <a href="/login?return_to=#{URI.encode_www_form(return_to)}">Try again</a>
      </body>
      </html>
      """)
    end
  end

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
