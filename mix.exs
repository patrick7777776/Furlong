defmodule Furlong.MixProject do
  use Mix.Project

  def project do
    [
      app: :furlong,
      version: "0.2.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/patrick7777776/Furlong",
      docs: [extras: ["intro.md"]]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Furlong: An Elixir port of the Kiwi Solver / Cassowary incremental constraint solving toolkit."
  end

  defp package() do
    [
      name: "furlong",
      licenses: ["Apache 2"],
      links: %{"GitHub" => "https://github.com/patrick7777776/Furlong"}
    ]
  end
end
