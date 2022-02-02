defmodule BitUtils do
  @moduledoc """
  Utility for converting binary to list of floats
  """
  def to_float_list(binary) when bit_size(binary) < 64, do: []

  def to_float_list(binary) do
    <<f::float-little, rest::bits>> = binary
    [f | to_float_list(rest)]
  end
end
