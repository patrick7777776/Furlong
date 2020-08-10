defmodule Furlong.Row do
  import Furlong.Util, only: [near_zero?: 1]
  alias Furlong.Row
  alias Furlong.Symbol

  defstruct constant: 0, cells: %{}

  def new(), do: %Row{constant: 0, cells: %{}}
  def new(constant) when is_number(constant), do: %Row{constant: constant, cells: %{}}

  def add(%Row{constant: constant} = row, value) when is_number(value),
    do: %Row{row | constant: constant + value}

  def insert(%Row{} = row, {:symbol, _type, _ref} = symbol), do: insert(row, symbol, 1)
  def insert(%Row{} = first, %Row{} = second), do: insert(first, second, 1)

  def insert(%Row{cells: cells} = row, {:symbol, _type, _ref} = symbol, coefficient)
      when is_number(coefficient) do
    updated_coefficient = Map.get(cells, symbol, 0) + coefficient

    if near_zero?(updated_coefficient) do
      %Row{row | cells: Map.delete(cells, symbol)}
    else
      %Row{row | cells: Map.put(cells, symbol, updated_coefficient)}
    end
  end

  def insert(
        %Row{cells: cells_1, constant: constant_1},
        %Row{cells: cells_2, constant: constant_2},
        coefficient
      )
      when is_number(coefficient) do
    %Row{
      constant: constant_1 + coefficient * constant_2,
      cells:
        cells_2
        |> Enum.reduce(cells_1, fn {symbol, coeff}, cells ->
          c = Map.get(cells, symbol, 0) + coeff * coefficient

          if near_zero?(c) do
            Map.delete(cells, symbol)
          else
            Map.put(cells, symbol, c)
          end
        end)
    }
  end

  def remove(%Row{cells: cells} = row, {:symbol, _, _} = symbol),
    do: %Row{row | cells: Map.delete(cells, symbol)}

  def reverse_sign(%Row{constant: constant, cells: cells}) do
    %Row{
      constant: -constant,
      cells:
        Enum.map(cells, fn {symbol, coefficient} -> {symbol, -coefficient} end) |> Enum.into(%{})
    }
  end

  def solve_for(%Row{constant: constant, cells: cells}, {:symbol, _, _} = symbol) do
    coefficient = -1.0 / Map.get(cells, symbol)

    %Row{
      constant: constant * coefficient,
      cells:
        cells
        |> Map.delete(symbol)
        |> Enum.map(fn {sym, coeff} -> {sym, coeff * coefficient} end)
        |> Enum.into(%{})
    }
  end

  def solve_for(%Row{} = row, {:symbol, _, _} = lhs, {:symbol, _, _} = rhs) do
    row
    |> insert(lhs, -1.0)
    |> solve_for(rhs)
  end

  def coefficient_for(%Row{cells: cells}, {:symbol, _, _} = symbol), do: Map.get(cells, symbol, 0)

  def substitute(%Row{cells: cells} = row, {:symbol, _, _} = symbol, %Row{} = subst) do
    case Map.get(cells, symbol) do
      nil ->
        row

      coefficient ->
        row
        |> remove(symbol)
        |> insert(subst, coefficient)
    end
  end

  def get_external_var(%Row{cells: cells}) do
    cells
    |> Map.keys()
    |> Enum.find(fn {:symbol, type, _} -> type == :external end)
  end

  def all_dummies?(%Row{cells: cells}) do
    cells
    |> Map.keys()
    |> Enum.all?(fn {:symbol, type, _} -> type == :dummy end)
  end

  def get_entering_symbol(%Row{cells: cells}) do
    case Enum.find(cells, fn {{:symbol, type, _}, value} -> type != :dummy and value < 0.0 end) do
      nil -> Symbol.invalid()
      {{:symbol, _type, _value} = symbol, _} -> symbol
    end
  end

  def any_pivotable_symbol(%Row{cells: cells}) do
    symbol =
      cells
      |> Map.keys()
      |> Enum.find(fn {:symbol, type, _} -> type == :slack or type == :error end)

    symbol || Symbol.invalid()
  end
end
