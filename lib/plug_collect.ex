defmodule PlugCollect do
  @moduledoc """
  Basic instrumentation library to intercept and collect Plug pipeline connection parameters for
  further reporting, monitoring or analysis with user provided callback functions.

  PlugCollect functionality is similar to this provided by `Plug.Conn.register_before_send/2`
  or `Plug.ErrorHandler`.

  PlugCollect registers a user defined callback "collectors" functions that will be applied before
  sending request response.
  Callback functions are applied always, even if request response pipeline fails.

  ### Usage
  Add `use PlugCollect` to your application's Phoenix endpoint or router with your callback
  functions defined with a required `:collectors` key as a list, for example:
  ```elixir
  #router.ex
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    use PlugCollect,
      collectors: [
        &MyApp.MyModule.my_collect1/2,
        {MyApp.MyModule, :my_collect2}
      ]
    # ...
  end
  ```

  Callback functions defined with a `:collectors` list have following characteristics:
  1. As a first argument callback function will receive an atom `:ok` or `:error` describing request
     pipeline processing status.
     `:ok` atom means that intercepted request was processed successfully by a Plug pipeline.
     `:error` means that during request processing, pipeline raised, exited or did throw an error.
  2. As a second argument function will receive a `Plug.Conn` struct with current pipeline
     connection. `Plug.Conn` struct is normalized using approach similar to this implemented in a
     `Plug.ErrorHandler`.
  3. Callback functions are applied after processing entire Plug pipeline defined below
     `use PlugCollect` statement.
  4. Functions are executed even if code declared after `use PlugCollect` raises, exits or throws an
     error.
  5. Callback functions are executed synchronously. They should not contain any blocking or costly IO
     operations, as it would delay or block sending request response to the user. Async processing
     can be easily achieved by using for example `spawn/1` in a collector function body.
  6. Callback functions results are ignored.
  7. Callback functions are executed in the order in which they appear in the `:collectors` list.
  8. Callback functions can be provided using anonymous function reference syntax or with
     `{module, function}` tuple.

  Example collector function implementation:
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
      @before_compile PlugCollect
      @collectors Keyword.fetch!(opts, :collectors)
    end
  end

  defmacro __before_compile__(_) do
    quote do
      defoverridable call: 2

      def call(conn, opts) do
        super(conn, opts)
      rescue
        error ->
          apply_collectors(:error, normalize_conn(error, conn))
          :erlang.raise(:error, error, __STACKTRACE__)
      catch
        kind, reason ->
          apply_collectors(:error, normalize_conn(reason, conn))
          :erlang.raise(kind, reason, __STACKTRACE__)
      else
        conn ->
          apply_collectors(:ok, conn)
          conn
      end

      defp apply_collectors(status, conn) do
        Enum.each(@collectors, fn collector ->
          case collector do
            c when is_function(c, 2) -> apply(c, [status, conn])
            {m, f} -> apply(m, f, [status, conn])
          end
        end)
      end

      defp normalize_conn(%{conn: conn, plug_status: status}, _conn),
        do: Plug.Conn.put_status(conn, status)

      defp normalize_conn(%{conn: conn}, _conn), do: conn
      defp normalize_conn(_err, %Plug.Conn{} = conn), do: conn
    end
  end
end
