# PlugCollect

[![Hex Version](https://img.shields.io/hexpm/v/plug_collect)](https://hex.pm/packages/plug_collect)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen)](https://hexdocs.pm/plug_collect)
[![CI](https://github.com/Recruitee/plug_collect/workflows/CI/badge.svg)](https://github.com/Recruitee/plug_collect/actions/workflows/ci.yml)

Basic instrumentation library to intercept and collect Plug pipeline connection parameters for
further reporting, monitoring or analysis with user provided function.

PlugCollect is inspired by other libraries:
* [Appsignal.Plug](https://github.com/appsignal/appsignal-elixir-plug),
* [Sentry.PlugCapture](https://github.com/getsentry/sentry-elixir).

## Installation
Add `plug_collect` to your application dependencies list in `mix.exs`:
```elixir
#mix.exs
def deps do
  [
    {:plug_collect, "~> 0.2.0"}
  ]
end
```

## Usage
Add `use PlugCollect` to your application's Phoenix endpoint or router, for example:
```elixir
#endpoint.ex
defmodule MyAppWeb.Endpoint do
  use PlugCollect, collectors: [&MyApp.Monitor.my_collect/2]
  use Phoenix.Endpoint, otp_app: :my_app
  # ...
```

Callback function `MyApp.Monitor.my_collect/2` will be invoked on each request.
Example `my_collect/2` callback implementation:
```elixir
defmodule MyApp.Monitor do
  def my_collect(_status, %Plug.Conn{assigns: assigns} = _conn),
    do: Logger.metadata(user_id: Map.get(assigns, :user_id))
end
```
