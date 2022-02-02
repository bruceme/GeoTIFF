defmodule GeoTIFF.MixProject do
  use Mix.Project

  @github "https://github.com/bruceme/GeoTIFF"

  def project do
    [
      app: :geotiff,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "GeoTIFF",
      source_url: @github,
      package: [
        description:
          "GeoTIFF -- reads specially formatted TIFF files that contain metadata abot the geographics transformation.",
        links: %{Github: @github},
        licenses: ["Apache 2"]
      ],
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
      #      {:exif_parser, "~> 0.2.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
