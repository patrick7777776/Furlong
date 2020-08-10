defmodule Furlong.Strength do
  @required {:strength, 1_001_001_000}
  @strong {:strength, 1_000_000}
  @medium {:strength, 1000}
  @weak {:strength, 1}

  def required(), do: @required
  def strong(), do: @strong
  def medium(), do: @medium
  def weak(), do: @weak

  def weaker_than?({:strength, s1}, {:strength, s2}), do: s1 < s2

  def clip({:strength, s}) do
    {:strength, req} = @required
    {:strength, max(0, min(s, req))}
  end
end
