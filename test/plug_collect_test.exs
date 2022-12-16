defmodule PlugCollectTest do
  defmodule CollectRouter do
    use Plug.Router
    use PlugCollect, collectors: [&__MODULE__.collect_anonymous/2, {__MODULE__, :collect_mf}]

    plug(:match)
    plug(:dispatch)

    get "/200" do
      send_resp(conn, 200, "200")
    end

    get "/404" do
      send_resp(conn, 404, "404")
    end

    get "/raise" do
      _ = conn
      raise RuntimeError, "Error"
    end

    get "/throw" do
      _ = conn
      throw(:throw_error)
    end

    get "/exit" do
      _ = conn
      exit(:exit_error)
    end

    get "/bad_request" do
      _ = conn
      raise %Plug.BadRequestError{}
    end

    get "/badarg" do
      _ = conn
      _ = String.to_integer("one")
    end

    def collect_anonymous(:ok, _conn), do: :persistent_term.put(:on_ok_anonymous, true)
    def collect_anonymous(:error, _conn), do: :persistent_term.put(:on_error_anonymous, true)
    def collect_mf(:ok, _conn), do: :persistent_term.put(:on_ok_mf, true)
    def collect_mf(:error, _conn), do: :persistent_term.put(:on_error_mf, true)
  end

  use ExUnit.Case, async: false
  use Plug.Test

  describe "collectors are always applied before sending response" do
    setup do
      :persistent_term.put(:on_ok_anonymous, false)
      :persistent_term.put(:on_error_anonymous, false)
      :persistent_term.put(:on_ok_mf, false)
      :persistent_term.put(:on_error_mf, false)
    end

    test "200" do
      conn = :get |> conn("/200") |> CollectRouter.call([])
      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "200"

      assert ok_request()
    end

    test "404" do
      conn = :get |> conn("/404") |> CollectRouter.call([])
      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "404"

      assert ok_request()
    end

    test "raise" do
      assert_raise Plug.Conn.WrapperError, "** (RuntimeError) Error", fn ->
        :get |> conn("/raise") |> CollectRouter.call([])
      end

      assert error_request()
    end

    test "throw" do
      assert :get |> conn("/throw") |> CollectRouter.call([]) |> catch_throw() == :throw_error

      assert error_request()
    end

    test "exit" do
      assert :get |> conn("/exit") |> CollectRouter.call([]) |> catch_exit() == :exit_error

      assert error_request()
    end

    test "bad_request" do
      assert_raise Plug.Conn.WrapperError,
                   "** (Plug.BadRequestError) could not process the request due to client error",
                   fn ->
                     :get |> conn("/bad_request") |> CollectRouter.call([])
                   end

      assert error_request()
    end

    test "badarg" do
      assert_raise Plug.Conn.WrapperError, fn ->
        :get |> conn("/badarg") |> CollectRouter.call([])
      end

      assert error_request()
    end
  end

  defp ok_request() do
    :persistent_term.get(:on_ok_anonymous) and :persistent_term.get(:on_ok_mf) and
      not (:persistent_term.get(:on_error_anonymous) and :persistent_term.get(:on_error_mf))
  end

  defp error_request() do
    not (:persistent_term.get(:on_ok_anonymous) and :persistent_term.get(:on_ok_mf)) and
      (:persistent_term.get(:on_error_anonymous) and :persistent_term.get(:on_error_mf))
  end
end
