defmodule PlugCollect.MixProject do
  use Mix.Project

  @source_url "https://github.com/Recruitee/plug_collect"
  @version "0.1.1"

  def project do
    [
      app: :plug_collect,
      version: @version,
      name: "PlugCollect",
      description: "Instrumentation library to intercept and collect Plug requests.",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application(), do: []

  defp deps() do
    [
      {:ex_doc, "~> 0.28.0", only: :dev, runtime: false},
      {:plug, ">= 1.1.0"}
    ]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs CHANGELOG.md README.md),
      maintainers: ["Recruitee", "Andrzej Magdziarz"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
