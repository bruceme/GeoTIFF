defmodule GeoTIFF do
  @moduledoc """
  This library reads specially formatted TIFF files that contain metadata abot the geographics transformation.
  This implimentation is specific to TIFF files sourced from NOAA charts.

  Lambert Conformal Conic to Geographic Transformation Formulae

  See https://www.linz.govt.nz/data/geodetic-system/coordinate-conversion/projection-conversions/lambert-conformal-conic-geographic
  """

  # These are the parameters used to convert geographic lat/long to pixel row/col
  defstruct xRes: 0, yRes: 0, easting: 0, northing: 0, p0: 0,l0: 0,p1: 0,p2: 0,n: 0,f: 0,rho0: 0

  @f 1.0 / 298.257222101004 # elipsoid constant
  @e :math.sqrt(2 * @f - @f * @f) # elipsoid function
  @a 6378137.0 # semi-major axis length (in meters)


  @doc """
  Parse the tiff headers for Geo TIFF related tags,
    then generate and calculte the parameters required
    to transform pixels to coordinates and vise versa.

  ## Examples

      iex> geotiff = GeoTIFF.parse_geotiff_file("res/Sample.tiff")
      %GeoTIFF{
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

  """
  def parse_geotiff_file(filename) do
    {:ok, tags} = ExifParser.parse_tiff_file(filename)
    doubles = BitUtils.toFloatList(tags.ifd0.geo_doubleparams)

    hasScale = Map.has_key?(tags.ifd0, :geo_pixelscale)

    keymap = Enum.chunk_every(tags.ifd0.geo_keydirectory, 4)
      |> Map.new(fn row ->
        [key,_,_,value] = row
        {key, value}
        end)

    p0 = Enum.at(doubles,keymap[3085]) |> d2r # ProjFalseOriginLatGeoKey
    l0 = Enum.at(doubles,keymap[3084]) |> d2r # ProjFalseOriginLongGeoKey
    p1 = Enum.at(doubles,keymap[3078]) |> d2r # ProjStdParallel1GeoKey
    p2 = Enum.at(doubles,keymap[3079]) |> d2r # ProjStdParallel2GeoKey

    {n,f,rho0} = compute_projections({p0,p1,p2})

    if hasScale do
      [yRes,xRes,_] = BitUtils.toFloatList(tags.ifd0.geo_pixelscale)
      [_,_,_,easting,northing,_] = BitUtils.toFloatList(tags.ifd0.geo_tiepoints)
      %GeoTIFF{xRes: -xRes, yRes: yRes, easting: -easting, northing: -northing, p0: p0, l0: l0, p1: p1,p2: p2, n: n, f: f, rho0: rho0 }
    else
      [yRes,_,_,easting,_,xRes,_,northing] = BitUtils.toFloatList(tags.ifd0.geo_transmatrix)
      %GeoTIFF{xRes: xRes, yRes: yRes, easting: -easting, northing: -northing, p0: p0, l0: l0, p1: p1,p2: p2, n: n, f: f, rho0: rho0 }
    end
  end

@doc """
  Given geotiff struct, convert the coordinate to a pixel offset

  ## Examples

      iex> pix = GeoTIFF.coord_to_pixel(GeoTIFF.parse_geotiff_file("res/Sample.tiff"), {-95, 39})
      {5212, 5934}

  """
  def coord_to_pixel(g, coord) do
    {longitude, latitude} = coord
    l = d2r(longitude)
    p = d2r(latitude)

    gamma = g.n * (l - g.l0)

    rho = @a * g.f * :math.pow(t(p), g.n)

    e = g.easting + (rho * :math.sin(gamma))
    n = g.northing + g.rho0 - (rho * :math.cos(gamma))

    {Kernel.trunc(e / -g.xRes),Kernel.trunc(n / -g.yRes)}
  end

  @doc """
  Given geotiff struct, convert a pixel offset to world coordinates

  ## Examples

      iex> pix = GeoTIFF.pixel_to_coord(GeoTIFF.parse_geotiff_file("res/Sample.tiff"), {5212, 5934})
      {-95.00004816930117, 38.99942684432852}

  """
  def pixel_to_coord(g, pixel) do
    {col,row} = pixel
    e = (col * -g.xRes) - g.easting
    n = (row * -g.yRes) - g.northing

    rhoN = g.rho0 - n

    rho2 = :math.sqrt(e * e + rhoN * rhoN)

    t = :math.pow(rho2 / (@a * g.f), 1.0 / g.n)

    phi = :math.atan(e / (g.rho0 - n))

    # First approximation
    p = inv_phi(t)

    esinphi = @e * :math.sin(p)

    # Second for elipsoid
    p = r2d(inv_phi(t *
        :math.pow((1.0 - esinphi) / (1.0 + esinphi), @e / 2.0)))

    l = r2d((phi / g.n) + g.l0)

    {l, p}
  end


  defp compute_projections(ps) do
    {p0,p1,p2} = ps
    m1 = m(p1)
    m2 = m(p2)
    t0 = t(p0)
    t1 = t(p1)
    t2 = t(p2)

    n = (:math.log(m1) - :math.log(m2)) /
        (:math.log(t1) - :math.log(t2))

    f = m1 / (n * :math.pow(t1, n))
    rho0 = @a * f * :math.pow(t0, n)

    {n,f,rho0}
  end

  defp d2r(deg), do: (deg * :math.pi) / 180.0

  defp r2d(rad), do: 180.0 * rad / :math.pi

  defp m(phi) do
    sinPhi = :math.sin(phi)
    :math.cos(phi) / :math.sqrt(1.0 - (@e * @e * sinPhi * sinPhi));
  end

  defp t(phi) do
    sinPhi = :math.sin(phi)
    :math.tan((:math.pi / 4.0) - (phi / 2.0)) /
          :math.pow((1.0 - @e * sinPhi) / (1.0 + @e * sinPhi) ,
            @e / 2.0)
  end

  defp inv_phi(phi), do: (:math.pi / 2.0) - 2.0 * :math.atan(phi)
end
