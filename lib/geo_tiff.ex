defmodule GeoTIFF do
  @moduledoc """
  This library reads specially formatted TIFF files that contain metadata abot the geographics transformation.
  This implimentation is specific to TIFF files sourced from NOAA charts.

  Lambert Conformal Conic to Geographic Transformation Formulae

  See https://www.linz.govt.nz/data/geodetic-system/coordinate-conversion/projection-conversions/lambert-conformal-conic-geographic
  """

  # These are the parameters used to convert geographic lat/long to pixel row/col
  defstruct x_res: 0,
            y_res: 0,
            easting: 0,
            northing: 0,
            p0: 0,
            l0: 0,
            p1: 0,
            p2: 0,
            n: 0,
            f: 0,
            rho_0: 0

  # elipsoid constant
  @f 1.0 / 298.257222101004
  # elipsoid function
  @e :math.sqrt(2 * @f - @f * @f)
  # semi-major axis length (in meters)
  @a 6_378_137.0

  @doc """
  Parse the tiff headers for Geo TIFF related tags,
    then generate and calculte the parameters required
    to transform pixels to coordinates and vise versa.

  ## Examples

      iex> GeoTIFF.parse_geotiff_file("res/Sample.tiff")
      %GeoTIFF{
              easting: 110334.52652367248,
              f: 1.952412414857403,
              l0: -1.6580627893946132,
              n: 0.630496251388787,
              northing: -85146.60133479013,
              p0: 0.6870779488684344,
              p1: 0.7853981633974483,
              p2: 0.5759586531581288,
              rho_0: 7788636.19968158,
              x_res: -21.168529658732837,
              y_res: 21.16791991605589
            }
  """
  def parse_geotiff_file(filename) do
    {:ok, tags} = ExifParser.parse_tiff_file(filename)
    doubles = BitUtils.to_float_list(tags.ifd0.geo_doubleparams)

    has_scale = Map.has_key?(tags.ifd0, :geo_pixelscale)

    keymap =
      Enum.chunk_every(tags.ifd0.geo_keydirectory, 4)
      |> Map.new(fn row ->
        [key, _, _, value] = row
        {key, value}
      end)

    # ProjFalseOriginLatGeoKey
    p0 = Enum.at(doubles, keymap[3085]) |> d2r
    # ProjFalseOriginLongGeoKey
    l0 = Enum.at(doubles, keymap[3084]) |> d2r
    # ProjStdParallel1GeoKey
    p1 = Enum.at(doubles, keymap[3078]) |> d2r
    # ProjStdParallel2GeoKey
    p2 = Enum.at(doubles, keymap[3079]) |> d2r

    {n, f, rho_0} = compute_projections({p0, p1, p2})

    if has_scale do
      [y_res, x_res, _] = BitUtils.to_float_list(tags.ifd0.geo_pixelscale)
      [_, _, _, easting, northing, _] = BitUtils.to_float_list(tags.ifd0.geo_tiepoints)

      %GeoTIFF{
        x_res: -x_res,
        y_res: y_res,
        easting: -easting,
        northing: -northing,
        p0: p0,
        l0: l0,
        p1: p1,
        p2: p2,
        n: n,
        f: f,
        rho_0: rho_0
      }
    else
      [y_res, _, _, easting, _, x_res, _, northing] =
        BitUtils.to_float_list(tags.ifd0.geo_transmatrix)

      %GeoTIFF{
        x_res: x_res,
        y_res: y_res,
        easting: -easting,
        northing: -northing,
        p0: p0,
        l0: l0,
        p1: p1,
        p2: p2,
        n: n,
        f: f,
        rho_0: rho_0
      }
    end
  end

  @doc """
  Given geotiff struct, convert the coordinate to a pixel offset

  ## Examples

      iex> GeoTIFF.coord_to_pixel(GeoTIFF.parse_geotiff_file("res/Sample.tiff"), {-95, 39})
      {5212, 5934}

  """
  def coord_to_pixel(g, coord) do
    {longitude, latitude} = coord
    l = d2r(longitude)
    p = d2r(latitude)

    gamma = g.n * (l - g.l0)

    rho = @a * g.f * :math.pow(t(p), g.n)

    e = g.easting + rho * :math.sin(gamma)
    n = g.northing + g.rho_0 - rho * :math.cos(gamma)

    {Kernel.trunc(e / -g.x_res), Kernel.trunc(n / -g.y_res)}
  end

  @doc """
  Given geotiff struct, convert a pixel offset to world coordinates

  ## Examples

      iex> GeoTIFF.pixel_to_coord(GeoTIFF.parse_geotiff_file("res/Sample.tiff"), {5212, 5934})
      {-95.00004816930117, 38.999426844328546}

  """
  def pixel_to_coord(g, pixel) do
    {col, row} = pixel
    e = col * -g.x_res - g.easting
    n = row * -g.y_res - g.northing

    rho_n = g.rho_0 - n

    rho2 = :math.sqrt(e * e + rho_n * rho_n)

    t = :math.pow(rho2 / (@a * g.f), 1.0 / g.n)

    phi = :math.atan(e / (g.rho_0 - n))

    # First approximation
    p = inv_phi(t)

    esinphi = @e * :math.sin(p)

    # Second for elipsoid
    p =
      r2d(
        inv_phi(
          t *
            :math.pow((1.0 - esinphi) / (1.0 + esinphi), @e / 2.0)
        )
      )

    l = r2d(phi / g.n + g.l0)

    {l |> Float.round(15), p |> Float.round(15)}
  end

  defp compute_projections(ps) do
    {p0, p1, p2} = ps
    m1 = m(p1)
    m2 = m(p2)
    t0 = t(p0)
    t1 = t(p1)
    t2 = t(p2)

    n =
      (:math.log(m1) - :math.log(m2)) /
        (:math.log(t1) - :math.log(t2))

    f = m1 / (n * :math.pow(t1, n))
    rho_0 = @a * f * :math.pow(t0, n)

    # some environments get rounding errors
    {n |> Float.round(15), f|> Float.round(15), rho_0|> Float.round(15)}
  end

  defp d2r(deg), do: deg * :math.pi() / 180.0

  defp r2d(rad), do: 180.0 * rad / :math.pi()

  defp m(phi) do
    sin_phi = :math.sin(phi)
    :math.cos(phi) / :math.sqrt(1.0 - @e * @e * sin_phi * sin_phi)
  end

  defp t(phi) do
    sin_phi = :math.sin(phi)

    :math.tan(:math.pi() / 4.0 - phi / 2.0) /
      :math.pow(
        (1.0 - @e * sin_phi) / (1.0 + @e * sin_phi),
        @e / 2.0
      )
  end

  defp inv_phi(phi), do: :math.pi() / 2.0 - 2.0 * :math.atan(phi)
end
