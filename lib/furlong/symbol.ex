defmodule Furlong.Symbol do
  @moduledoc """
  Markers that are used internally by the Solver.
  """

  def invalid(), do: {:symbol, :invalid, make_ref()}
  def external(), do: {:symbol, :external, make_ref()}
  def slack(), do: {:symbol, :slack, make_ref()}
  def error(), do: {:symbol, :error, make_ref()}
  def dummy(), do: {:symbol, :dummy, make_ref()}
end
