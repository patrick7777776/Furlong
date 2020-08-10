defmodule Furlong.Symbol do
  def invalid(), do: {:symbol, :invalid, make_ref()}
  def external(), do: {:symbol, :external, make_ref()}
  def slack(), do: {:symbol, :slack, make_ref()}
  def error(), do: {:symbol, :error, make_ref()}
  def dummy(), do: {:symbol, :dummy, make_ref()}
end
