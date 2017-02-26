defmodule ExOauth2Provider.Plug.EnsureAuthenticatedTest do
  @moduledoc false
  use ExOauth2Provider.TestCase
  use Plug.Test

  import ExOauth2Provider.Factory
  import ExOauth2Provider.PlugHelpers

  alias ExOauth2Provider.Plug.EnsureAuthenticated
  alias ExOauth2Provider.OauthAccessToken
  alias ExOauth2Provider.Test.Repo

  defmodule TestHandler do
    @moduledoc false

    def unauthenticated(conn, _) do
      conn
      |> Plug.Conn.assign(:ex_oauth2_provider_spec, :unauthenticated)
      |> Plug.Conn.send_resp(401, "Unauthenticated")
    end
  end

  setup do
    user = insert(:user)
    attrs = params_for(:access_token, %{resource_owner_id: user.id})
    {_, access_token} = Repo.insert(OauthAccessToken.create_changeset(%OauthAccessToken{}, attrs))

    {
      :ok,
      conn: conn(:get, "/foo"),
      access_token: access_token
    }
  end

  test "init/1 sets the handler option to the module that's passed in" do
    %{handler: handler_opts} = EnsureAuthenticated.init(handler: TestHandler)

    assert handler_opts == {TestHandler, :unauthenticated}
  end

  test "init/1 defaults the handler option to ExOauth2Provider.Plug.ErrorHandler" do
    %{handler: handler_opts} = EnsureAuthenticated.init %{}

    assert handler_opts == {ExOauth2Provider.Plug.ErrorHandler, :unauthenticated}
  end

  test "init/1 with default options" do
    options = EnsureAuthenticated.init %{}

    assert options == %{
      handler: {ExOauth2Provider.Plug.ErrorHandler, :unauthenticated},
      key: :default
    }
  end

  test "doesn't call unauth when valid token for default key", context do
    ensured_conn =
      context.conn
      |> ExOauth2Provider.Plug.set_current_token(context.access_token)
      |> run_plug(EnsureAuthenticated, handler: TestHandler)

    refute must_authenticate?(ensured_conn)
  end

  test "doesn't call unauthenticated when valid token for key", context do
    ensured_conn =
      context.conn
      |> ExOauth2Provider.Plug.set_current_token(context.access_token, :secret)
      |> run_plug(EnsureAuthenticated, handler: TestHandler, key: :secret)

    refute must_authenticate?(ensured_conn)
  end

  test "calls unauthenticated with no token for default key", context do
    ensured_conn = run_plug(context.conn, EnsureAuthenticated, handler: TestHandler)

    assert must_authenticate?(ensured_conn)
  end

  test "calls unauthenticated when no token for key", context do
    ensured_conn = run_plug(
      context.conn,
      EnsureAuthenticated,
      handler: TestHandler,
      key: :secret
    )

    assert must_authenticate?(ensured_conn)
  end

  test "it halts the connection", context do
    ensured_conn = run_plug(
      context.conn,
      EnsureAuthenticated,
      handler: TestHandler,
      key: :secret
    )

    assert ensured_conn.halted
  end

  defp must_authenticate?(conn) do
    conn.assigns[:ex_oauth2_provider_spec] == :unauthenticated
  end
end
