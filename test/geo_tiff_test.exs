defmodule GeoTIFFTest do
  use ExUnit.Case
  doctest GeoTIFF

  test "read tiff header" do
    {:ok, tags} = ExifParser.parse_tiff_file("res/Sample.tiff")
    doubles = BitUtils.toFloatList(tags.ifd0.geo_doubleparams)
    assert Enum.any?(doubles)
  end

  test "Fuzzy pixel to coordinate" do
    geotiff = GeoTIFF.parse_geotiff_file("res/Sample.tiff")

    {lng, lat} = GeoTIFF.pixel_to_coord(geotiff, {5212, 5934})
    assert abs(lng - -95.0) < 0.001
    assert abs(lat - 39.0) < 0.001
  end
end
