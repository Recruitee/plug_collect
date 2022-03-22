defmodule PlugCollectTest do
  defmodule CollectRouter do
    use Plug.Router
    use PlugCollect, collect_fun: &__MODULE__.collect_request/2

    plug(:match)
    plug(:dispatch)

    get "/200" do
      send_resp(conn, 200, "200")
    end

    match "/404" do
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

    def collect_request(:ok, _conn), do: :persistent_term.put(:on_success, true)
    def collect_request(:error, _conn), do: :persistent_term.put(:on_error, true)
  end

  use ExUnit.Case, async: false
  use Plug.Test

  describe ":collect_fun callback function is always invoked before sending response" do
    setup do
      :persistent_term.put(:on_success, false)
      :persistent_term.put(:on_error, false)
    end

    test "200" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)
      conn = :get |> conn("/200") |> CollectRouter.call([])
      assert :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)
      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "200"
    end

    test "404" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)
      conn = :get |> conn("/404") |> CollectRouter.call([])
      assert :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)
      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "404"
    end

    test "raise" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)

      assert_raise Plug.Conn.WrapperError, "** (RuntimeError) Error", fn ->
        :get |> conn("/raise") |> CollectRouter.call([])
      end

      refute :persistent_term.get(:on_success)
      assert :persistent_term.get(:on_error)
    end

    test "throw" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)

      assert :get |> conn("/throw") |> CollectRouter.call([]) |> catch_throw() == :throw_error

      refute :persistent_term.get(:on_success)
      assert :persistent_term.get(:on_error)
    end

    test "exit" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)

      assert :get |> conn("/exit") |> CollectRouter.call([]) |> catch_exit() == :exit_error

      refute :persistent_term.get(:on_success)
      assert :persistent_term.get(:on_error)
    end

    test "bad_request" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)

      assert_raise Plug.Conn.WrapperError,
                   "** (Plug.BadRequestError) could not process the request due to client error",
                   fn ->
                     :get |> conn("/bad_request") |> CollectRouter.call([])
                   end

      refute :persistent_term.get(:on_success)
      assert :persistent_term.get(:on_error)
    end

    test "badarg" do
      refute :persistent_term.get(:on_success)
      refute :persistent_term.get(:on_error)

      assert_raise Plug.Conn.WrapperError, "** (ArgumentError) argument error", fn ->
        :get |> conn("/badarg") |> CollectRouter.call([])
      end

      refute :persistent_term.get(:on_success)
      assert :persistent_term.get(:on_error)
    end
  end
end
