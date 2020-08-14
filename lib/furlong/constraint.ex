defmodule Furlong.Constraint do
  @moduledoc """
  Provides an experimental macro for expressing constraints in a 'natural' way.

  With constraint macro:
  ```
  import Furlong.Constraint
  {x, y} = {make_ref(), make_ref()}
  constraint = constraint(3*x >= y/2-5)
  ```

  Without constraint macro:
  ```
  import Furlong.Symbolics
  {x, y} = {make_ref(), make_ref()}
  constraint = gte(multiply(3, x), subtract(divide(y, 2), 5))
  ```
  """

  @doc """
  Converts an expression into corresponding calls to Furlong.Symbolics.
  """
  defmacro constraint(expression) do
    Macro.postwalk(expression, fn 
      {:*, _meta, [left, right]} -> quote do Furlong.Symbolics.multiply(unquote(left), unquote(right)) end
      {:/, _meta, [left, right]} -> quote do Furlong.Symbolics.divide(unquote(left), unquote(right)) end
      {:+, _meta, [left, right]} -> quote do Furlong.Symbolics.add(unquote(left), unquote(right)) end
      {:-, _meta, [child]} when is_number(child) -> -child
      {:-, _meta, [child]} -> quote do Furlong.Symbolics.negate(unquote(child)) end
      {:-, _meta, [left, right]} -> quote do Furlong.Symbolics.subtract(unquote(left), unquote(right)) end
      {:>=, _meta, [left, right]} -> quote do Furlong.Symbolics.gte(unquote(left), unquote(right)) end
      {:<=, _meta, [left, right]} -> quote do Furlong.Symbolics.lte(unquote(left), unquote(right)) end
      {:==, _meta, [left, right]} -> quote do Furlong.Symbolics.eq(unquote(left), unquote(right)) end
      other -> other
    end)
  end

end
