defmodule Furlong.Strength do
  @moduledoc """
  Standard constraint strengths.

  Solver functions generally offer shortcuts via atoms :required, :strong, :medium, :weak.
  """

  @required {:strength, 1_001_001_000}
  @strong {:strength, 1_000_000}
  @medium {:strength, 1000}
  @weak {:strength, 1}

  @doc """
  Required (highest strength).
  """
  def required(), do: @required

  @doc """
  Strong constraint strength. 
  """
  def strong(), do: @strong

  @doc """
  Medium constraint strength.
  """
  def medium(), do: @medium

  @doc """
  Weak (lowest strength).
  """
  def weak(), do: @weak

  @doc """
  Tests whether first constraint strength is weaker than second constraint strength.
  """
  def weaker_than?({:strength, s1}, {:strength, s2}), do: s1 < s2

  @doc """
  Clips given constraint strength at a maximum of required strength.
  """
  def clip({:strength, s}) do
    {:strength, req} = @required
    {:strength, max(0, min(s, req))}
  end
end
