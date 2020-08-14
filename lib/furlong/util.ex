defmodule Furlong.Util do
  @moduledoc """
  Utility functions.
  """

  @doc"""
  Tests whether a value is sufficiently close to 0.
  """
  def near_zero?(value) when is_number(value) and value < 0, do: -value < 1.0e-8
  def near_zero?(value) when is_number(value), do: value < 1.0e-8

  @doc"""
  Creates a list of n new variables (refs).
  """
  def new_vars(n) when is_number(n) and n > 0, do: Enum.map(0..(n - 1), fn _ -> make_ref() end)
end
