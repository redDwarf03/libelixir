defmodule ArchethicClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :archethic_client,
      version: "0.1.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      consolidate_protocols: Mix.env() == :prod
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ArchethicClient.Application, []}
    ]
  end

  # Added function
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specify dialyzer path
  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Web
      {:req, "~> 0.5"},
      # Currently using fork waiting for issue: https://github.com/CargoSense/absinthe_client/issues/19
      {:absinthe_client, git: "https://github.com/Neylix/absinthe_client.git"},

      # Utils
      {:decimal, "~> 2.0"},

      # Dev
      {:plug, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
