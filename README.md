# GeoTIFF

This library reads specially formatted TIFF files that contain metadata abot the geographics transformation.
This implimentation is specific to TIFF files sourced from NOAA charts.

Lambert Conformal Conic to Geographic Transformation Formulae

See https://www.linz.govt.nz/data/geodetic-system/coordinate-conversion/projection-conversions/lambert-conformal-conic-geographic
 

## Installation

The package can be installed by adding `geotiff` to your list of dependencies in `mix.exs` as follows:

```elixir
def deps do
  [
    {:geotiff, "~> 0.1.0"}
  ]
end
```