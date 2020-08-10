defmodule Furlong.Symbolics do
  def multiply(var, coefficient) when is_reference(var) and is_number(coefficient),
    do: {:term, var, coefficient}

  def multiply(coefficient, var) when is_reference(var) and is_number(coefficient),
    do: {:term, var, coefficient}

  def multiply({:term, var, coeff}, coefficient) when is_number(coefficient),
    do: {:term, var, coeff * coefficient}

  def multiply(coefficient, {:term, var, coeff}) when is_number(coefficient),
    do: {:term, var, coeff * coefficient}

  def multiply({:expression, terms, constant}, coefficient) when is_number(coefficient) do
    multiplied_terms = Enum.map(terms, fn term -> multiply(term, coefficient) end)
    {:expression, multiplied_terms, constant * coefficient}
  end

  def multiply(coefficient, {:expression, _, _} = expression) when is_number(coefficient),
    do: multiply(expression, coefficient)

  def multiply({:expression, _, _} = expression, {:expression, [], constant}),
    do: multiply(expression, constant)

  def multiply({:expression, [], constant}, {:expression, _, _} = expression),
    do: multiply(expression, constant)

  def divide(var, denominator) when is_reference(var) and is_number(denominator),
    do: {:term, var, 1.0 / denominator}

  def divide({:term, var, coefficient}, denominator) when is_number(denominator),
    do: {:term, var, coefficient * (1.0 / denominator)}

  def divide({:expression, _, _} = expression, denominator) when is_number(denominator),
    do: multiply(expression, 1.0 / denominator)

  def divide({:expression, _, _} = expression, {:expression, [], constant}),
    do: divide(expression, constant)

  def negate(var) when is_reference(var), do: {:term, var, -1}
  def negate({:term, var, coefficient}), do: {:term, var, -coefficient}
  def negate({:expression, _, _} = expression), do: multiply(expression, -1)

  def add(c1, c2) when is_number(c1) and is_number(c2), do: c1 + c2

  def add({:term, _, _} = term, constant) when is_number(constant),
    do: {:expression, [term], constant}

  def add(constant, {:term, _, _} = term) when is_number(constant),
    do: {:expression, [term], constant}

  def add({:term, _, _} = term, var) when is_reference(var),
    do: {:expression, [term, {:term, var, 1}], 0}

  def add(var, {:term, _, _} = term) when is_reference(var),
    do: {:expression, [term, {:term, var, 1}], 0}

  def add({:term, _, _} = first, {:term, _, _} = second), do: {:expression, [first, second], 0}

  def add({:expression, terms, constant}, const) when is_number(const),
    do: {:expression, terms, constant + const}

  def add(const, {:expression, terms, constant}) when is_number(const),
    do: {:expression, terms, constant + const}

  def add({:expression, terms, constant}, var) when is_reference(var),
    do: {:expression, [{:term, var, 1} | terms], constant}

  def add(var, {:expression, terms, constant}) when is_reference(var),
    do: {:expression, [{:term, var, 1} | terms], constant}

  def add({:expression, terms, constant}, {:term, _, _} = term),
    do: {:expression, [term | terms], constant}

  def add({:term, _, _} = term, {:expression, terms, constant}),
    do: {:expression, [term | terms], constant}

  def add({:expression, terms_1, constant_1}, {:expression, terms_2, constant_2}),
    do: {:expression, terms_1 ++ terms_2, constant_1 + constant_2}

  def add(var, constant) when is_number(constant) and is_reference(var),
    do: {:expression, [{:term, var, 1}], constant}

  def add(constant, var) when is_number(constant) and is_reference(var), do: add(var, constant)

  def add(first, second) when is_reference(first) and is_reference(second),
    do: add(first, {:expression, [{:term, second, 1}], 0})

  def subtract({:expression, _, _} = expression, constant) when is_number(constant),
    do: add(expression, -constant)

  def subtract(constant, {:expression, _, _} = expression) when is_number(constant),
    do: add(negate(expression), constant)

  def subtract({:expression, _, _} = expression, var) when is_reference(var),
    do: add(expression, negate(var))

  def subtract(var, {:expression, _, _} = expression) when is_reference(var),
    do: add(var, negate(expression))

  def subtract({:expression, _, _} = expression, {:term, _, _} = term),
    do: add(expression, negate(term))

  def subtract({:term, _, _} = term, {:expression, _, _} = expression),
    do: add(negate(expression), term)

  def subtract({:expression, _, _} = first, {:expression, _, _} = second),
    do: add(first, negate(second))

  def subtract({:term, _, _} = term, constant) when is_number(constant), do: add(term, -constant)

  def subtract(constant, {:term, _, _} = term) when is_number(constant),
    do: add(negate(term), constant)

  def subtract({:term, _, _} = term, var) when is_reference(var), do: add(term, negate(var))
  def subtract(var, {:term, _, _} = term) when is_reference(var), do: add(var, negate(term))
  def subtract({:term, _, _} = first, {:term, _, _} = second), do: add(first, negate(second))

  def subtract(var, constant) when is_number(constant) and is_reference(var),
    do: add(var, -constant)

  def subtract(constant, var) when is_number(constant) and is_reference(var),
    do: add(negate(var), constant)

  def subtract(first, second) when is_reference(first) and is_reference(second),
    do: add(first, negate(second))

  def eq(first, second), do: rel(:eq, first, second)
  def lte(first, second), do: rel(:lte, first, second)
  def gte(first, second), do: rel(:gte, first, second)

  defp rel(op, {:expression, _, _} = first, {:expression, _, _} = second),
    do: {:constraint, reduce(subtract(first, second)), op}

  defp rel(op, {:expression, _, _} = expression, {:term, _, _} = term),
    do: {:constraint, reduce(subtract(expression, {:expression, [term], 0})), op}

  defp rel(op, {:term, _, _} = term, {:expression, _, _} = expression),
    do: rel(op, {:expression, [term], 0}, expression)

  defp rel(op, {:expression, _, _} = expression, var) when is_reference(var),
    do: rel(op, expression, {:term, var, 1})

  defp rel(op, var, {:expression, _, _} = expression) when is_reference(var),
    do: rel(op, {:term, var, 1}, expression)

  defp rel(op, {:expression, _, _} = expression, constant) when is_number(constant),
    do: rel(op, expression, {:expression, [], constant})

  defp rel(op, constant, {:expression, _, _} = expression) when is_number(constant),
    do: rel(op, {:expression, [], constant}, expression)

  defp rel(op, {:term, _, _} = first, {:term, _, _} = second),
    do: rel(op, {:expression, [first], 0}, second)

  defp rel(op, {:term, _, _} = term, var) when is_reference(var),
    do: rel(op, {:expression, [term], 0}, var)

  defp rel(op, var, {:term, _, _} = term) when is_reference(var),
    do: rel(op, var, {:expression, [term], 0})

  defp rel(op, {:term, _, _} = term, constant) when is_number(constant),
    do: rel(op, {:expression, [term], 0}, constant)

  defp rel(op, constant, {:term, _, _} = term) when is_number(constant),
    do: rel(op, constant, {:expression, [term], 0})

  defp rel(op, first, second) when is_reference(first) and is_reference(second),
    do: rel(op, {:term, first, 1}, second)

  defp rel(op, var, const) when is_reference(var) and is_number(const),
    do: rel(op, {:term, var, 1}, const)

  defp rel(op, const, var) when is_reference(var) and is_number(const),
    do: rel(op, const, {:term, var, 1})

  def reduce({:expression, terms, constant}) do
    reduced_terms =
      terms
      |> Enum.reduce(%{}, fn {:term, var, coefficient}, summed_coefficients ->
        Map.update(summed_coefficients, var, coefficient, fn sum -> sum + coefficient end)
      end)
      |> Enum.map(fn {var, coefficient} -> {:term, var, coefficient} end)

    {:expression, reduced_terms, constant}
  end
end
