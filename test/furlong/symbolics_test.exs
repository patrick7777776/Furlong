defmodule Furlong.SymbolicsTest do
  use ExUnit.Case

  import Furlong.Symbolics

  test "variable multiply, divide, negate" do
    x = make_ref()

    assert multiply(x, 1) == {:term, x, 1}
    assert multiply(x, 0) == {:term, x, 0}
    assert multiply(x, -1) == {:term, x, -1}
    assert multiply(x, 5) == {:term, x, 5}

    assert multiply(x, 1) == multiply(1, x)
    assert multiply(x, 0) == multiply(0, x)
    assert multiply(x, -1) == multiply(-1, x)
    assert multiply(x, 5) == multiply(5, x)

    assert divide(x, 1) == {:term, x, 1}
    assert divide(x, 2) == {:term, x, 1 / 2}

    assert_raise ArithmeticError, fn ->
      divide(x, 0)
    end

    assert negate(x) == {:term, x, -1}
  end

  test "term multiply, divide, negate" do
    x = make_ref()
    assert multiply({:term, x, 1}, 5) == {:term, x, 5}
    assert multiply({:term, x, 1}, 5) == multiply(5, {:term, x, 1})

    assert divide({:term, x, 5}, 5) == {:term, x, 1}

    assert negate({:term, x, 3}) == {:term, x, -3}
  end

  test "adding a var and a var" do
    x = make_ref()
    y = make_ref()
    assert add(x, y) == {:expression, [{:term, x, 1}, {:term, y, 1}], 0}
  end

  test "adding a var and a constant" do
    x = make_ref()
    assert add(x, 123) == {:expression, [{:term, x, 1}], 123}
    assert add(123, x) == {:expression, [{:term, x, 1}], 123}
  end

  test "adding a term and a constant" do
    x = make_ref()
    assert add({:term, x, 1}, 7.777776) == {:expression, [{:term, x, 1}], 7.777776}
    assert add(7.777776, {:term, x, 1}) == {:expression, [{:term, x, 1}], 7.777776}
  end

  test "adding a term and variable" do
    x = make_ref()
    y = make_ref()
    assert add({:term, x, 1}, y) == {:expression, [{:term, x, 1}, {:term, y, 1}], 0}
    assert add(y, {:term, x, 1}) == {:expression, [{:term, x, 1}, {:term, y, 1}], 0}
  end

  test "adding two terms" do
    x = make_ref()
    y = make_ref()
    assert add({:term, x, 1}, {:term, y, 2}) == {:expression, [{:term, x, 1}, {:term, y, 2}], 0}
    assert add({:term, y, 2}, {:term, x, 1}) == {:expression, [{:term, y, 2}, {:term, x, 1}], 0}
  end

  test "adding an expression and a constant" do
    x = make_ref()
    expression = {:expression, [{:term, x, 1}], -12}
    assert add(expression, 13) == {:expression, [{:term, x, 1}], 1}
    assert add(13, expression) == {:expression, [{:term, x, 1}], 1}
  end

  test "adding an expression and a variable" do
    x = make_ref()
    y = make_ref()
    expression = {:expression, [{:term, x, 7}], 6}
    assert add(expression, y) == {:expression, [{:term, y, 1}, {:term, x, 7}], 6}
    assert add(y, expression) == {:expression, [{:term, y, 1}, {:term, x, 7}], 6}
  end

  test "adding an expression and a term" do
    x = make_ref()
    y = make_ref()
    expression = {:expression, [{:term, x, 1}], -12}
    term = {:term, y, 1}
    assert add(expression, term) == {:expression, [{:term, y, 1}, {:term, x, 1}], -12}
    assert add(term, expression) == {:expression, [{:term, y, 1}, {:term, x, 1}], -12}
  end

  test "adding two expressions" do
    x = make_ref()
    y = make_ref()
    ex_1 = {:expression, [{:term, x, 1}], 5}
    ex_2 = {:expression, [{:term, x, 1}, {:term, y, 2}], 2}
    assert add(ex_1, ex_2) == {:expression, [{:term, x, 1}, {:term, x, 1}, {:term, y, 2}], 7}
    assert add(ex_2, ex_1) == {:expression, [{:term, x, 1}, {:term, y, 2}, {:term, x, 1}], 7}
  end

  test "multiply an expression with a constant" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 2}, {:term, y, 9}], 5}
    assert multiply(ex, 3) == {:expression, [{:term, x, 6}, {:term, y, 27}], 15}
    assert multiply(3, ex) == {:expression, [{:term, x, 6}, {:term, y, 27}], 15}
  end

  test "multiply an expression with a (constant) expression" do
    x = make_ref()
    ex_1 = {:expression, [{:term, x, 2}], 5}
    ex_c = {:expression, [], 4}
    assert multiply(ex_1, ex_c) == {:expression, [{:term, x, 8}], 20}
    assert multiply(ex_1, ex_c) == multiply(ex_c, ex_1)
  end

  test "negate an expression" do
    x = make_ref()
    assert negate({:expression, [{:term, x, 3}], 4}) == {:expression, [{:term, x, -3}], -4}
  end

  test "divide an expression by a constant" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 6}, {:term, y, 9}], 3}
    assert divide(ex, 3) == {:expression, [{:term, x, 2}, {:term, y, 3}], 1}
  end

  test "divide an expression by a (constant) expression" do
    x = make_ref()
    ex_1 = {:expression, [{:term, x, 10}], 5}
    ex_c = {:expression, [], 5}
    assert divide(ex_1, ex_c) == {:expression, [{:term, x, 2}], 1}
  end

  test "subtract a constant from an expression" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 10}, {:term, y, 3}], 50}
    assert subtract(ex, 5) == {:expression, [{:term, x, 10}, {:term, y, 3}], 45}
    assert subtract(5, ex) == {:expression, [{:term, x, -10}, {:term, y, -3}], -45}
  end

  test "subtract a variable from an expression" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 10}], 50}
    assert subtract(ex, x) == {:expression, [{:term, x, -1}, {:term, x, 10}], 50}
    assert subtract(ex, y) == {:expression, [{:term, y, -1}, {:term, x, 10}], 50}
    assert subtract(x, ex) == {:expression, [{:term, x, 1}, {:term, x, -10}], -50}
    assert subtract(y, ex) == {:expression, [{:term, y, 1}, {:term, x, -10}], -50}
  end

  test "subtract a term from an expression" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 10}], 50}
    term = {:term, y, 5}
    assert subtract(ex, term) == {:expression, [{:term, y, -5}, {:term, x, 10}], 50}
    assert subtract(term, ex) == {:expression, [{:term, y, 5}, {:term, x, -10}], -50}
  end

  test "subtract an expression from an expression" do
    x = make_ref()
    y = make_ref()
    z = make_ref()
    ex_1 = {:expression, [{:term, x, 10}, {:term, z, -3}], 50}
    ex_2 = {:expression, [{:term, y, 20}, {:term, z, -3}], -5}

    assert subtract(ex_1, ex_2) ==
             {:expression, [{:term, x, 10}, {:term, z, -3}, {:term, y, -20}, {:term, z, 3}], 55}

    assert subtract(ex_2, ex_1) ==
             {:expression, [{:term, y, 20}, {:term, z, -3}, {:term, x, -10}, {:term, z, 3}], -55}
  end

  test "subtract a constant from a term" do
    x = make_ref()
    assert subtract({:term, x, 10}, 5) == {:expression, [{:term, x, 10}], -5}
    assert subtract(5, {:term, x, 10}) == {:expression, [{:term, x, -10}], 5}
  end

  test "subtract a variable from a term" do
    x = make_ref()
    y = make_ref()
    assert subtract({:term, x, 10}, x) == {:expression, [{:term, x, 10}, {:term, x, -1}], 0}
    assert subtract({:term, x, 10}, y) == {:expression, [{:term, x, 10}, {:term, y, -1}], 0}
    assert subtract(x, {:term, x, 10}) == {:expression, [{:term, x, -10}, {:term, x, 1}], 0}
    assert subtract(y, {:term, x, 10}) == {:expression, [{:term, x, -10}, {:term, y, 1}], 0}
  end

  test "subtract a term from a term" do
    x = make_ref()

    assert subtract({:term, x, 10}, {:term, x, 5}) ==
             {:expression, [{:term, x, 10}, {:term, x, -5}], 0}

    assert subtract({:term, x, 5}, {:term, x, 10}) ==
             {:expression, [{:term, x, 5}, {:term, x, -10}], 0}
  end

  test "subtract a constant from a var" do
    x = make_ref()
    assert subtract(x, 1) == {:expression, [{:term, x, 1}], -1}
    assert subtract(1, x) == {:expression, [{:term, x, -1}], 1}
  end

  test "subtract a var from a var" do
    x = make_ref()
    y = make_ref()
    assert subtract(x, x) == {:expression, [{:term, x, -1}, {:term, x, 1}], 0}
    assert subtract(x, y) == {:expression, [{:term, y, -1}, {:term, x, 1}], 0}
    assert subtract(y, x) == {:expression, [{:term, x, -1}, {:term, y, 1}], 0}
  end

  test "constraint from two expressions" do
    x = make_ref()
    y = make_ref()
    first = {:expression, [{:term, x, 10}], 33}
    second = {:expression, [{:term, y, 20}], 16}

    assert eq(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, y, -20}], 17}), :eq}

    assert eq(second, first) ==
             {:constraint, reduce({:expression, [{:term, y, 20}, {:term, x, -10}], -17}), :eq}

    assert lte(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, y, -20}], 17}), :lte}

    assert lte(second, first) ==
             {:constraint, reduce({:expression, [{:term, y, 20}, {:term, x, -10}], -17}), :lte}

    assert gte(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, y, -20}], 17}), :gte}

    assert gte(second, first) ==
             {:constraint, reduce({:expression, [{:term, y, 20}, {:term, x, -10}], -17}), :gte}
  end

  test "constraint from an expression and a term" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 10}], 33}
    term = {:term, y, 20}

    assert eq(ex, term) ==
             {:constraint, {:expression, [{:term, x, 10}, {:term, y, -20}], 33}, :eq}

    assert eq(term, ex) ==
             {:constraint, {:expression, [{:term, x, -10}, {:term, y, 20}], -33}, :eq}

    assert lte(ex, term) ==
             {:constraint, {:expression, [{:term, x, 10}, {:term, y, -20}], 33}, :lte}

    assert lte(term, ex) ==
             {:constraint, {:expression, [{:term, x, -10}, {:term, y, 20}], -33}, :lte}

    assert gte(ex, term) ==
             {:constraint, {:expression, [{:term, x, 10}, {:term, y, -20}], 33}, :gte}

    assert gte(term, ex) ==
             {:constraint, {:expression, [{:term, x, -10}, {:term, y, 20}], -33}, :gte}
  end

  test "constraint from an expression and a var" do
    x = make_ref()
    y = make_ref()
    ex = {:expression, [{:term, x, 10}], 33}
    assert eq(ex, y) == {:constraint, {:expression, [{:term, x, 10}, {:term, y, -1}], 33}, :eq}
    assert eq(y, ex) == {:constraint, {:expression, [{:term, x, -10}, {:term, y, 1}], -33}, :eq}
    assert lte(ex, y) == {:constraint, {:expression, [{:term, x, 10}, {:term, y, -1}], 33}, :lte}
    assert lte(y, ex) == {:constraint, {:expression, [{:term, x, -10}, {:term, y, 1}], -33}, :lte}
    assert gte(ex, y) == {:constraint, {:expression, [{:term, x, 10}, {:term, y, -1}], 33}, :gte}
    assert gte(y, ex) == {:constraint, {:expression, [{:term, x, -10}, {:term, y, 1}], -33}, :gte}
  end

  test "eq constraint from an expression and a constant" do
    x = make_ref()
    ex = {:expression, [{:term, x, 10}], 33}
    assert eq(ex, 10) == {:constraint, {:expression, [{:term, x, 10}], 23}, :eq}
    assert eq(10, ex) == {:constraint, {:expression, [{:term, x, -10}], -23}, :eq}
    assert lte(ex, 10) == {:constraint, {:expression, [{:term, x, 10}], 23}, :lte}
    assert lte(10, ex) == {:constraint, {:expression, [{:term, x, -10}], -23}, :lte}
    assert gte(ex, 10) == {:constraint, {:expression, [{:term, x, 10}], 23}, :gte}
    assert gte(10, ex) == {:constraint, {:expression, [{:term, x, -10}], -23}, :gte}
  end

  test "eq constraint from two terms" do
    x = make_ref()
    first = {:term, x, 10}
    second = {:term, x, 5}

    assert eq(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -5}], 0}), :eq}

    assert eq(second, first) ==
             {:constraint, reduce({:expression, [{:term, x, 5}, {:term, x, -10}], 0}), :eq}

    assert lte(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -5}], 0}), :lte}

    assert lte(second, first) ==
             {:constraint, reduce({:expression, [{:term, x, 5}, {:term, x, -10}], 0}), :lte}

    assert gte(first, second) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -5}], 0}), :gte}

    assert gte(second, first) ==
             {:constraint, reduce({:expression, [{:term, x, 5}, {:term, x, -10}], 0}), :gte}
  end

  test "eq constraint from a term and a variable" do
    x = make_ref()
    term = {:term, x, 10}

    assert eq(term, x) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -1}], 0}), :eq}

    assert eq(x, term) ==
             {:constraint, reduce({:expression, [{:term, x, -10}, {:term, x, 1}], 0}), :eq}

    assert lte(term, x) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -1}], 0}), :lte}

    assert lte(x, term) ==
             {:constraint, reduce({:expression, [{:term, x, -10}, {:term, x, 1}], 0}), :lte}

    assert gte(term, x) ==
             {:constraint, reduce({:expression, [{:term, x, 10}, {:term, x, -1}], 0}), :gte}

    assert gte(x, term) ==
             {:constraint, reduce({:expression, [{:term, x, -10}, {:term, x, 1}], 0}), :gte}
  end

  test "eq constraint from a term and a constant" do
    x = make_ref()
    term = {:term, x, 10}
    assert eq(term, 5) == {:constraint, {:expression, [{:term, x, 10}], -5}, :eq}
    assert eq(5, term) == {:constraint, {:expression, [{:term, x, -10}], 5}, :eq}
    assert lte(term, 5) == {:constraint, {:expression, [{:term, x, 10}], -5}, :lte}
    assert lte(5, term) == {:constraint, {:expression, [{:term, x, -10}], 5}, :lte}
    assert gte(term, 5) == {:constraint, {:expression, [{:term, x, 10}], -5}, :gte}
    assert gte(5, term) == {:constraint, {:expression, [{:term, x, -10}], 5}, :gte}
  end

  test "eq constraint from two variables" do
    x = make_ref()
    y = make_ref()
    assert eq(x, y) == {:constraint, {:expression, [{:term, x, 1}, {:term, y, -1}], 0}, :eq}
    assert gte(x, y) == {:constraint, {:expression, [{:term, x, 1}, {:term, y, -1}], 0}, :gte}
    assert lte(x, y) == {:constraint, {:expression, [{:term, x, 1}, {:term, y, -1}], 0}, :lte}
  end

  test "eq constraint from a variable and a constant" do
    x = make_ref()
    assert eq(x, 23.42) == {:constraint, {:expression, [{:term, x, 1}], -23.42}, :eq}
    assert eq(23.42, x) == {:constraint, {:expression, [{:term, x, -1}], 23.42}, :eq}
    assert lte(x, 23.42) == {:constraint, {:expression, [{:term, x, 1}], -23.42}, :lte}
    assert lte(23.42, x) == {:constraint, {:expression, [{:term, x, -1}], 23.42}, :lte}
    assert gte(x, 23.42) == {:constraint, {:expression, [{:term, x, 1}], -23.42}, :gte}
    assert gte(23.42, x) == {:constraint, {:expression, [{:term, x, -1}], 23.42}, :gte}
  end

  test "reducing expressions" do
    x = make_ref()
    y = make_ref()

    assert reduce({:expression, [{:term, x, 10}, {:term, x, -1}, {:term, x, -9}], 123}) ==
             {:expression, [{:term, x, 0}], 123}

    assert reduce({:expression, [{:term, x, 10}, {:term, x, -1}, {:term, y, -9}], -1}) ==
             {:expression, [{:term, x, 9}, {:term, y, -9}], -1}
  end

  test "kiwi example" do
    x1 = make_ref()
    x2 = make_ref()

    assert gte(x2, add(x1, 10)) ==
             {:constraint, {:expression, [{:term, x1, -1}, {:term, x2, 1}], -10}, :gte}
  end
end
