defmodule VaultexTest do
  use ExUnit.Case
  doctest Vaultex

  setup context do
    {:ok, client} = Vaultex.Client.start(name: context[:test])

    on_exit fn ->
      GenServer.stop(client)
    end

    {:ok, client: client}
  end

  test "Authentication of app_role with role_id is successful", %{client: client} do
    assert Vaultex.Client.auth(:app_role, {"vaultex_test_role_id"}, client)
      == {:ok, :authenticated}
  end

  test "Authentication of app_role with role_id and secret_id is successful", %{client: client} do
    assert Vaultex.Client.auth(:app_role,
        {"vaultex_secret_id_test_role_id",
         "vaultex_secret_id_test_role_id_secret_id"}, client)
      == {:ok, :authenticated}
  end

  test "Authentication of app_role with role_id but without secret_id is unsuccessful", %{client: client} do
    assert Vaultex.Client.auth(:app_role,
        {"vaultex_secret_id_test_role_id"}, client)
      == {:error, ["failed to validate SecretID: missing secret_id"]}
  end

  test "Authentication of userpass is successful", %{client: client} do
    assert Vaultex.Client.auth(:userpass, {"vaultex", "vaultex_password"}, client)
      == {:ok, :authenticated}
  end

  test "Authentication of userpass is unsuccessful", %{client: client} do
    assert Vaultex.Client.auth(:userpass, {"vaultex", "bad"}, client)
      == {:error, ["invalid username or password"]}
  end

  test "Read of key with app_role is successful", %{client: client} do
    assert Vaultex.Client.read("secret/allow/key", :app_role, {"vaultex_test_role_id"}, client)
      == {:ok, %{"name" => "data", "value" => "123"}}
  end

  test "Read of key without permission with role_id, secret_id returns error", %{client: client} do
    assert Vaultex.Client.read("secret/deny/key", :app_role,
        {"vaultex_secret_id_test_role_id",
         "vaultex_secret_id_test_role_id_secret_id"}, client)
      == {:error, ["permission denied"]}
  end

  test "Read of key with invalid secret_id returns error", %{client: client} do
    assert Vaultex.Client.read("secret/allow/key", :app_role,
        {"vaultex_secret_id_test_role_id",
         "invalid_secret"}, client)
      == {:error, ["failed to validate SecretID: invalid secret_id \"invalid_secret\""]}
  end

  test "Read of key with userpass is successful", %{client: client} do
    assert Vaultex.Client.read("secret/allow/key", :userpass, {"vaultex", "vaultex_password"}, client)
      == {:ok, %{"name" => "data", "value" => "123"}}
  end

  test "Read of key without permission with userpass returns error", %{client: client} do
    assert Vaultex.Client.read("secret/deny/key", :userpass, {"vaultex", "vaultex_password"}, client)
      == {:error, ["permission denied"]}
  end

  test "Read of key with invalid userpass returns error", %{client: client} do
    assert Vaultex.Client.read("secret/allow/key", :userpass, {"vaultex", "invalid_password"}, client)
      == {:error, ["invalid username or password"]}
  end
end
