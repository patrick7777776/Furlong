defmodule Furlong.SolverTest do
  use ExUnit.Case

  import Furlong.Solver
  import Furlong.Symbolics

  @epsilon 1.0e-8

  test "simple new" do
    x = make_ref()
    constraint = eq(add(x, 2), 20)

    solver =
      new()
      |> add_constraint(constraint, :required)

    assert_in_delta value?(solver, x), 18, @epsilon
  end

  test "simple 0" do
    x = make_ref()
    y = make_ref()

    solver =
      new()
      |> add_constraint(eq(x, 20))
      |> add_constraint(eq(add(x, 2), add(y, 10)))

    assert_in_delta value?(solver, x), 20, @epsilon
    assert_in_delta value?(solver, y), 12, @epsilon
  end

  test "simple 1" do
    x = make_ref()
    y = make_ref()

    solver =
      new()
      |> add_constraint(eq(x, y))

    assert_in_delta value?(solver, x), value?(solver, y), @epsilon
  end

  test "casso 1" do
    x = make_ref()
    y = make_ref()

    solver =
      new()
      |> add_constraint(lte(x, y))
      |> add_constraint(eq(y, add(x, 3)))
      |> add_constraint(eq(x, 10), :weak)
      |> add_constraint(eq(y, 10), :weak)

    if abs(value?(solver, x) - 10) < @epsilon do
      assert_in_delta value?(solver, x), 10, @epsilon
      assert_in_delta value?(solver, y), 13, @epsilon
    else
      assert_in_delta value?(solver, x), 7, @epsilon
      assert_in_delta value?(solver, y), 10, @epsilon
    end
  end

  test "inconsistent 1" do
    x = make_ref()

    assert_raise RuntimeError, fn ->
      new()
      |> add_constraint(eq(x, 10))
      |> add_constraint(eq(x, 5))
    end
  end

  test "inconsistent 2" do
    x = make_ref()

    assert_raise RuntimeError, fn ->
      new()
      |> add_constraint(gte(x, 10))
      |> add_constraint(lte(x, 5))
    end
  end

  test "inconsistent 3" do
    w = make_ref()
    x = make_ref()
    y = make_ref()
    z = make_ref()

    assert_raise RuntimeError, fn ->
      new()
      |> add_constraint(gte(w, 10))
      |> add_constraint(gte(x, w))
      |> add_constraint(gte(y, x))
      |> add_constraint(gte(z, y))
      |> add_constraint(gte(z, 8))
      |> add_constraint(lte(z, 4))
    end
  end

  test "add delete 1" do
    x = make_ref()

    solver =
      new()
      |> add_constraint(lte(x, 100), :weak)

    assert_in_delta value?(solver, x), 100, @epsilon

    c10 = lte(x, 10)
    c20 = lte(x, 20)

    solver =
      solver
      |> add_constraint(c10)
      |> add_constraint(c20)

    assert_in_delta value?(solver, x), 10, @epsilon

    solver =
      solver
      |> remove_constraint(c10)

    assert_in_delta value?(solver, x), 20, @epsilon

    solver =
      solver
      |> remove_constraint(c20)

    assert_in_delta value?(solver, x), 100, @epsilon

    assert_raise RuntimeError, fn ->
      new()
      |> add_constraint(lte(x, 10))
      |> add_constraint(lte(x, 10))
    end
  end

  test "add delete 2" do
    x = make_ref()
    y = make_ref()
    c10 = lte(x, 10)
    c20 = lte(x, 20)

    solver =
      new()
      |> add_constraint(eq(x, 100), :weak)
      |> add_constraint(eq(y, 120), :strong)
      |> add_constraint(c10)
      |> add_constraint(c20)

    assert_in_delta value?(solver, x), 10, @epsilon
    assert_in_delta value?(solver, y), 120, @epsilon

    solver =
      solver
      |> remove_constraint(c10)

    assert_in_delta value?(solver, x), 20, @epsilon
    assert_in_delta value?(solver, y), 120, @epsilon

    cxy = eq(multiply(x, 2), y)

    solver =
      solver
      |> add_constraint(cxy)

    assert_in_delta value?(solver, x), 20, @epsilon
    assert_in_delta value?(solver, y), 40, @epsilon

    solver =
      solver
      |> remove_constraint(c20)

    assert_in_delta value?(solver, x), 60, @epsilon
    assert_in_delta value?(solver, y), 120, @epsilon

    solver =
      solver
      |> remove_constraint(cxy)

    assert_in_delta value?(solver, x), 100, @epsilon
    assert_in_delta value?(solver, y), 120, @epsilon
  end

  test "duplicate constraint is rejected" do
    solver = new()
    x = make_ref()
    constraint = {:constraint, {:expression, [{:term, x, 1}], -23.42}, :gte}
    solver = add_constraint(solver, constraint, :strong)

    assert_raise RuntimeError, fn ->
      add_constraint(solver, constraint, :medium)
    end
  end

  test "removing unknown constraint" do
    assert_raise RuntimeError, fn ->
      new()
      |> remove_constraint({:constraint, {:expression, [{:term, make_ref(), 1}], 23.42}, :gte})
    end
  end

  test "inequality example 1" do
    x = make_ref()

    solver =
      new()
      |> add_constraint(lte(100, x))

    assert 100 <= value?(solver, x)

    solver =
      solver
      |> add_constraint(eq(x, 110))

    assert_in_delta value?(solver, x), 110, @epsilon
  end

  test "inequality example 2" do
    x = make_ref()

    solver =
      new()
      |> add_constraint(gte(100, x))

    assert 100 >= value?(solver, x)

    solver =
      solver
      |> add_constraint(eq(x, 90))

    assert_in_delta value?(solver, x), 90, @epsilon
  end

  test "kiwi example" do
    x1 = make_ref()
    x2 = make_ref()
    xm = make_ref()

    solver =
      new()
      |> add_constraint(gte(x1, 0))
      |> add_constraint(lte(x2, 100))
      |> add_constraint(gte(x2, add(x1, 10)))
      |> add_constraint(eq(xm, divide(add(x1, x2), 2)))

    assert_in_delta value?(solver, x1), 0, @epsilon
    assert_in_delta value?(solver, x2), 100, @epsilon
    assert_in_delta value?(solver, xm), 50, @epsilon

    solver =
      solver
      |> add_constraint(eq(x1, 40), :weak)

    assert_in_delta value?(solver, x1), 40, @epsilon
    assert_in_delta value?(solver, x2), 100, @epsilon
    assert_in_delta value?(solver, xm), 70, @epsilon

    solver =
      solver
      |> add_edit_variable(xm, :strong)
      |> suggest_value(xm, 60)

    assert_in_delta value?(solver, x1), 40, @epsilon
    assert_in_delta value?(solver, x2), 80, @epsilon
    assert_in_delta value?(solver, xm), 60, @epsilon

    solver =
      solver
      |> suggest_value(xm, 90)

    assert_in_delta value?(solver, x1), 80, @epsilon
    assert_in_delta value?(solver, x2), 100, @epsilon
    assert_in_delta value?(solver, xm), 90, @epsilon
  end
end
