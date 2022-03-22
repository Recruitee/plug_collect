defmodule PlugCollect do
  @moduledoc """
  Basic instrumentation library to intercept and collect Plug pipeline connection parameters for
  further reporting, monitoring or analysis with user provided callback function.

  Functionality provided by PlugCollect is very similar to one offered by
  `Plug.Conn.register_before_send/2` function.
  `register_before_send/2` registers a callback to be invoked before the response is sent.
  When using `register_before_send/2`, user defined callback will not be invoked if response
  processing pipeline raises.

  PlugCollect similarly to `register_before_send/2` registers a callback to be invoked before
  sending response, however callback function is always executed, even if response pipeline fails.

  ### Usage
  Add `use PlugCollect` to your application's Phoenix endpoint or router, for example:
  ```elixir
  #router.ex
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    use PlugCollect, collect_fun: &MyApp.MyModule.my_collect/2
    # ...
  end
  ```

  Using `PlugCollect` **requires** `:collect_fun` parameter specifying a user defined
  callback function with two arity.

  Callback function defined by `:collect_fun` key has following characteristics:
  1. As a first argument function will receive an atom `:ok` or `:error` describing request
     pipeline processing status.
     `:ok` atom means that intercepted request was processed successfully by Plug pipeline.
     `:error` means that during request processing, pipeline raised, exited or did throw an error.
  2. As a second argument function will receive a `Plug.Conn` struct with current pipeline
     connection.
  3. Callback function is invoked on each Plug request, after processing entire Plug pipeline
     defined below `use PlugCollect` statement.
  4. Function is executed even if code declared after `use PlugCollect` raises, exits or throws an
     error.
  5. Callback function is executed synchronously. It should not contain any blocking or costly IO
     operations, as it would delay or block sending request response to the user.
  6. Callback function result is ignored.

  Example `:collect_fun` implementation:
  ```elixir
  defmodule MyApp.MyModule do
    def my_collect(:ok, %Plug.Conn{assigns: assigns} = _conn),
      do: Logger.metadata(user_id: Map.get(assigns, :user_id))
    def my_collect(_status, _conn), do: :ok
  end
  ```
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @collect_fun Keyword.fetch!(opts, :collect_fun)

      def call(conn, opts) do
        super(conn, opts)
      rescue
        error ->
          apply(@collect_fun, [:error, prepare_conn(error, conn)])
          :erlang.raise(:error, error, __STACKTRACE__)
      catch
        kind, reason ->
          apply(@collect_fun, [:error, prepare_conn(reason, conn)])
          :erlang.raise(kind, reason, __STACKTRACE__)
      else
        conn ->
          apply(@collect_fun, [:ok, conn])
          conn
      end

      def prepare_conn(%{conn: conn, plug_status: status}, _conn) when is_integer(status),
        do: Map.put(conn, :status, status)

      def prepare_conn(%{conn: conn}, _conn), do: conn
      def prepare_conn(_err, %Plug.Conn{} = conn), do: conn

      defoverridable call: 2
    end
  end
end
