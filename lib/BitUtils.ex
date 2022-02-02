defmodule BitUtils do
  def toFloatList(binary) when bit_size(binary) < 64, do: []

  def toFloatList(binary) do
    <<f::float-little, rest::bits>> = binary
    [f | toFloatList(rest)]
  end

  def toGeoMap([head | tail]) do
    [value | newTail] = Enum.drop(tail, 3)
    [{head, value} | toGeoMap(newTail)]
  end
end
