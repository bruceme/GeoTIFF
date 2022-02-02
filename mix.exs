defmodule GeoTIFF.MixProject do
  use Mix.Project

  def project do
    [
      app: :geotiff,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "GeoTIFF",
      source_url: "https://github.com/bruceme/GeoTIFF",
      docs: [
        # The main page in the docs
        main: "GeoTIFF",
        logo: "res/GeoTIFF_Logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exif_parser, github: "bruceme/exif_parser", branch: "feature/geotiff"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
