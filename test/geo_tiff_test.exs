defmodule GeoTIFFTest do
  use ExUnit.Case
  doctest GeoTIFF

  test "greets the world" do
    assert GeoTIFF.hello() == :world
  end

  test "read tiff header" do
    {:ok, tags} = ExifParser.parse_tiff_file("res/Sample.tiff")
    doubles = BitUtils.toFloatList(tags.ifd0.geo_doubleparams)
    assert Enum.any?(doubles)
  end

  test "get geotiff params" do
    geotiff = GeoTIFF.parse_geotiff_file("res/Sample.tiff")

    assert geotiff == %GeoTIFF{
      easting: 110334.52652367248,
      f: 1.9524124148574027,
      l0: -1.6580627893946132,
      n: 0.6304962513887873,
      northing: -85146.60133479013,
      p0: 0.6870779488684344,
      p1: 0.7853981633974483,
      p2: 0.5759586531581288,
      rho0: 7788636.19968158,
      xRes: -21.168529658732837,
      yRes: 21.16791991605589
    }
  end

  test "Coordinate to Pixel" do
    geotiff = GeoTIFF.parse_geotiff_file("res/Sample.tiff")

    pix = GeoTIFF.coord_to_pixel(geotiff, {-95, 39})
    assert pix == {5212, 5934}
  end

  test "Pixel to Coordinate" do
    geotiff = GeoTIFF.parse_geotiff_file("res/Sample.tiff")

    {lng, lat} = GeoTIFF.pixel_to_coord(geotiff, {5212, 5934})
    assert abs(lng - -95.0) < 0.001
    assert abs(lat - 39.0) < 0.001
  end

end
