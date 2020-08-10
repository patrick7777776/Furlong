defmodule Furlong.RowTest do
  use ExUnit.Case

  alias Furlong.Row
  import Furlong.Row
  alias Furlong.Symbol

  test "new" do
    assert new() == %Row{constant: 0, cells: %{}}
    assert new(123.45) == %Row{constant: 123.45, cells: %{}}
  end

  test "add" do
    assert new() |> add(27) == %Row{constant: 27, cells: %{}}

    sym = Symbol.external()

    row =
      new(3)
      |> insert(sym, 17)

    assert add(row, 5) == %Row{constant: 8, cells: %{sym => 17}}
  end

  test "insert symbol" do
    row = new()
    sym = Symbol.slack()
    row_2 = insert(row, sym)
    assert Map.get(row_2.cells, sym) == 1
  end

  test "insert symbol and coefficient" do
    row = new()
    sym = Symbol.invalid()
    coe = 7.777776
    row_2 = insert(row, sym, coe)
    assert Map.get(row_2.cells, sym) == coe

    row_3 = insert(row_2, sym, -coe)
    assert Map.get(row_3.cells, sym) == nil

    row_4 =
      row_3
      |> insert(sym, 1)
      |> insert(sym, 2)
      |> insert(sym, 3)

    assert Map.get(row_4.cells, sym) == 6
  end

  test "insert row" do
    sym_1 = Symbol.invalid()
    sym_2 = Symbol.external()
    sym_3 = Symbol.slack()
    sym_4 = Symbol.error()
    sym_5 = Symbol.dummy()

    row_1 =
      new()
      |> insert(sym_1)
      |> insert(sym_2)
      |> insert(sym_3)

    row_2 =
      new()
      |> insert(sym_3)
      |> insert(sym_4)
      |> insert(sym_5)

    row_12 = insert(row_1, row_2, 1)
    assert row_12.cells == %{sym_1 => 1, sym_2 => 1, sym_3 => 2, sym_4 => 1, sym_5 => 1}
    assert insert(row_1, row_2, 1) == insert(row_2, row_1, 1)
    assert insert(row_1, row_2) == insert(row_1, row_2, 1)

    row_122 = insert(row_1, row_2, 2)
    assert row_122.cells == %{sym_1 => 1, sym_2 => 1, sym_3 => 3, sym_4 => 2, sym_5 => 2}
    assert row_122.constant == 0

    row_3 =
      new(123)
      |> insert(sym_1, -1)

    row_4 =
      new(-10)
      |> insert(sym_1, 2)

    row_34 = insert(row_3, row_4, 0.5)
    assert row_34.constant == 118
    assert row_34.cells == %{}
  end

  test "remove symbol" do
    sym_1 = Symbol.external()
    sym_2 = Symbol.external()

    row =
      new()
      |> insert(sym_1, 15)
      |> insert(sym_2, 77)

    assert Map.get(row.cells, sym_2) == 77
    row_2 = remove(row, sym_2)
    assert Map.get(row_2.cells, sym_2) == nil
  end

  test "reverse sign" do
    sym_1 = Symbol.external()
    sym_2 = Symbol.external()

    row =
      new(777)
      |> insert(sym_1, 15)
      |> insert(sym_2, -77)

    assert row.constant == 777
    assert row.cells == %{sym_1 => 15, sym_2 => -77}

    reversed_row = reverse_sign(row)
    assert reversed_row.constant == -777
    assert reversed_row.cells == %{sym_1 => -15, sym_2 => 77}
  end

  test "solve for symbol" do
    sym_1 = Symbol.external()
    sym_2 = Symbol.external()

    row =
      new(100)
      |> insert(sym_1, 10)
      |> insert(sym_2, 20)

    solved = solve_for(row, sym_1)
    assert Map.get(solved.cells, sym_1) == nil
    assert solved.constant == 100 / -10
    assert Map.get(solved.cells, sym_2) == 20 / -10
  end

  test "solve for rhs, lhs symbol" do
    sym_1 = Symbol.external()

    row =
      new(100)
      |> insert(sym_1, 20)

    sym_2 = Symbol.external()
    solved = solve_for(row, sym_2, sym_1)
    assert Map.get(solved.cells, sym_1) == nil
    assert coefficient_for(solved, sym_1) == 0
    assert solved.constant == 100 / -20
    assert Map.get(solved.cells, sym_2) == -1 / -20
    assert coefficient_for(solved, sym_2) == 0.05
  end

  test "substitue row -- no op if symbol is not contained in row" do
    sym_1 = Symbol.external()

    row =
      new(100)
      |> insert(sym_1, 20)

    sym_2 = Symbol.external()

    row_2 =
      new(100)
      |> insert(sym_2, 20)

    assert substitute(row, sym_2, row_2) == row
  end

  test "get_external_var" do
    row =
      new()
      |> insert(Symbol.slack(), 1)

    assert Row.get_external_var(row) == nil

    row =
      new()
      |> insert(Symbol.slack(), 1)
      |> insert(Symbol.external(), 1)

    refute Row.get_external_var(row) == nil
  end

  test "all_dummies?" do
    row =
      new(100)
      |> insert(Symbol.dummy(), 1)
      |> insert(Symbol.dummy(), 2)
      |> insert(Symbol.dummy(), 3)

    assert Row.all_dummies?(row)

    row_2 = insert(row, Symbol.external(), 4)
    refute Row.all_dummies?(row_2)
  end

  test "get_entering_symbol" do
    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.dummy(), 1)
      |> get_entering_symbol

    assert type == :invalid

    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.dummy(), -1)
      |> insert(Symbol.external(), 0)
      |> get_entering_symbol

    assert type == :invalid

    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.dummy(), 1)
      |> insert(Symbol.dummy(), -1)
      |> insert(Symbol.external(), 0)
      |> insert(Symbol.external(), -1)
      |> get_entering_symbol

    assert type == :external
  end

  test "any_pivotable_symbol" do
    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.dummy(), 1)
      |> insert(Symbol.invalid(), 1)
      |> insert(Symbol.external(), 1)
      |> any_pivotable_symbol

    assert type == :invalid

    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.dummy(), -1)
      |> insert(Symbol.slack(), 1)
      |> any_pivotable_symbol

    assert type == :slack

    {:symbol, type, _} =
      new(100)
      |> insert(Symbol.external(), -1)
      |> insert(Symbol.error(), -1)
      |> any_pivotable_symbol

    assert type == :error
  end
end
