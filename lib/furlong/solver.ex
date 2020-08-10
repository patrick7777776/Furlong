defmodule Furlong.Solver do
  # i think kiwi docs say you shouldn't add the same constraint twice -- so the current check can stay as is
  # https://kiwisolver.readthedocs.io/en/latest/basis/basic_systems.html
  # Cassowary (and Kiwi) supports to have redundant constraints, meaning that even if having two constraints (x == 10, x + y == 30) is equivalent to a third one (y == 20), all three can be added to the solver without issue.  However, one should not add multiple times the same constraint (in the same form) to the solver. -- kiwijava gets this wrong I think...

  alias Furlong.Row
  alias Furlong.Solver
  alias Furlong.Symbol
  alias Furlong.Strength
  import Furlong.Util, only: [near_zero?: 1]

  # constraint -> tag
  defstruct cns: %{},
            # symbol -> row
            rows: %{},
            # variable (ref) -> symbol
            vars: %{},
            # variable -> edit_info
            edits: %{},
            # [symbol]
            infeasible_rows: [],
            objective: Row.new(),
            # Row
            artificial: nil,
            strengths: %{}

  def new(), do: %Solver{}

  def add_constraint(%Solver{} = solver, {:constraint, _, _} = constraint),
    do: add_constraint(solver, constraint, Strength.required())

  def add_constraint(%Solver{} = solver, {:constraint, _, _} = constraint, :required),
    do: add_constraint(solver, constraint, Strength.required())

  def add_constraint(%Solver{} = solver, {:constraint, _, _} = constraint, :strong),
    do: add_constraint(solver, constraint, Strength.strong())

  def add_constraint(%Solver{} = solver, {:constraint, _, _} = constraint, :medium),
    do: add_constraint(solver, constraint, Strength.medium())

  def add_constraint(%Solver{} = solver, {:constraint, _, _} = constraint, :weak),
    do: add_constraint(solver, constraint, Strength.weak())

  def add_constraint(
        %Solver{} = solver,
        {:constraint, _, _} = constraint,
        {:strength, _} = strength
      ) do
    if Map.has_key?(solver.cns, constraint) do
      raise "Duplicate constraint."
    end

    solver = %Solver{solver | strengths: Map.put(solver.strengths, constraint, strength)}

    {solver, row, tag} = create_row(solver, constraint, strength)
    {:symbol, type, _} = subject = choose_subject(solver, row, tag)

    subject =
      if type == :invalid and Row.all_dummies?(row) do
        if !near_zero?(row.constant) do
          raise "Unsatisfiable constraint."
        else
          {:tag, marker, _other} = tag
          marker
        end
      else
        subject
      end

    {:symbol, type, _} = subject

    solver =
      if type == :invalid do
        {solver, success} = add_with_artificial_variable(solver, row)

        if !success do
          raise "Unsatisfiable constraint."
        end

        solver
      else
        row = Row.solve_for(row, subject)
        solver = substitute(solver, subject, row)
        %Solver{solver | rows: Map.put(solver.rows, subject, row)}
      end

    solver = %Solver{solver | cns: Map.put(solver.cns, constraint, tag)}
    solver = optimize(solver, solver.objective)
    solver
  end

  defp create_row(
         %Solver{} = solver,
         {:constraint, {:expression, terms, constant}, op} = _constraint,
         {:strength, str_coeff} = strength
       ) do
    {solver, row} =
      terms
      |> Enum.reject(fn {:term, _var, coefficient} -> near_zero?(coefficient) end)
      |> Enum.reduce({solver, Row.new(constant)}, fn {:term, var, coefficient}, {solver, row} ->
        {solver, symbol} = var_symbol?(solver, var)

        row =
          case row?(solver, symbol) do
            nil ->
              Row.insert(row, symbol, coefficient)

            other_row ->
              Row.insert(row, other_row, coefficient)
          end

        {solver, row}
      end)

    {solver, row, tag} =
      if op == :eq do
        if Strength.weaker_than?(strength, Strength.required()) do
          err_plus = Symbol.error()
          err_minus = Symbol.error()

          row =
            row
            |> Row.insert(err_plus, -1)
            |> Row.insert(err_minus, 1)

          solver =
            solver
            |> insert_into_objective(err_plus, str_coeff)
            |> insert_into_objective(err_minus, str_coeff)

          {solver, row, {:tag, err_plus, err_minus}}
        else
          dummy = Symbol.dummy()
          row = Row.insert(row, dummy)
          {solver, row, {:tag, dummy, Symbol.invalid()}}
        end
      else
        coeff =
          if op == :lte do
            1.0
          else
            -1.0
          end

        slack = Symbol.slack()
        row = Row.insert(row, slack, coeff)

        if Strength.weaker_than?(strength, Strength.required()) do
          error = Symbol.error()
          row = Row.insert(row, error, -coeff)
          solver = insert_into_objective(solver, error, str_coeff)
          {solver, row, {:tag, slack, error}}
        else
          {solver, row, {:tag, slack, Symbol.invalid()}}
        end
      end

    row =
      if row.constant < 0 do
        Row.reverse_sign(row)
      else
        row
      end

    {solver, row, tag}
  end

  defp choose_subject(
         %Solver{} = _solver,
         %Row{} = row,
         {:tag, {:symbol, marker_type, _} = marker, {:symbol, other_type, _} = other} = _tag
       ) do
    external = Row.get_external_var(row)

    cond do
      external != nil ->
        external

      (marker_type == :slack or marker_type == :error) and Row.coefficient_for(row, marker) < 0 ->
        marker

      (other_type == :slack or other_type == :error) and Row.coefficient_for(row, other) < 0 ->
        other

      true ->
        Symbol.invalid()
    end
  end

  defp get_leaving_row(%Solver{rows: rows} = _solver, {:symbol, _type, _ref} = entering) do
    rows
    |> Enum.reduce({nil, nil}, fn {{:symbol, type, _} = _key, candidate_row},
                                  {ratio, _row} = best_so_far ->
      coefficient = Row.coefficient_for(candidate_row, entering)

      cond do
        type == :external ->
          best_so_far

        coefficient >= 0 ->
          best_so_far

        ratio != nil and -candidate_row.constant / coefficient >= ratio ->
          best_so_far

        true ->
          {-candidate_row.constant / coefficient, candidate_row}
      end
    end)
    |> elem(1)
  end

  defp optimize(%Solver{} = solver, %Row{} = objective) do
    {:symbol, type, _} = entering = Row.get_entering_symbol(objective)

    if type == :invalid do
      solver
    else
      entry = get_leaving_row(solver, entering)

      if entry == nil do
        raise "Objective function is unbounded -- internal solver error."
      end

      leaving =
        solver.rows
        |> Enum.find(fn {_key, row} -> row == entry end)
        |> elem(0)

      solver = %Solver{solver | rows: Map.delete(solver.rows, leaving)}
      entry = Row.solve_for(entry, leaving, entering)
      solver = substitute(solver, entering, entry)
      solver = %Solver{solver | rows: Map.put(solver.rows, entering, entry)}
      # The objective function can be the same as either solver.objective or
      # solver.artificial; in languages with mutability, there is a pointer alias
      # at play, but not so in Elixir. The || below leads to the same effect.
      solver = optimize(solver, solver.artificial || solver.objective)
      solver
    end
  end

  defp substitute(%Solver{} = solver, {:symbol, _, _} = symbol, %Row{} = row) do
    rows =
      solver.rows
      |> Enum.map(fn {s, r} -> {s, Row.substitute(r, symbol, row)} end)

    infeasible_rows =
      rows
      |> Enum.filter(fn {{:symbol, type, _}, r} -> type != :external and r.constant < 0 end)
      |> Enum.map(fn {s, _r} -> s end)

    objective = Row.substitute(solver.objective, symbol, row)

    artificial =
      if solver.artificial != nil do
        Row.substitute(solver.artificial, symbol, row)
      else
        nil
      end

    %Solver{
      solver
      | rows: Enum.into(rows, %{}),
        infeasible_rows: solver.infeasible_rows ++ infeasible_rows,
        artificial: artificial,
        objective: objective
    }
  end

  defp add_with_artificial_variable(%Solver{} = solver, %Row{} = row) do
    art = Symbol.slack()
    solver = %Solver{solver | rows: Map.put(solver.rows, art, row), artificial: row}
    solver = optimize(solver, solver.artificial)
    success = near_zero?(solver.artificial.constant)
    solver = %Solver{solver | artificial: nil}

    {solver, return, val} =
      case Map.get(solver.rows, art) do
        %Row{} = rowptr ->
          delete_queue =
            solver.rows
            |> Enum.filter(fn {_s, r} -> r == rowptr end)
            |> Enum.map(fn {s, _r} -> s end)

          solver =
            delete_queue
            |> Enum.reduce(solver, fn sym, sol ->
              %Solver{sol | rows: Map.delete(sol.rows, sym)}
            end)

          if map_size(rowptr.cells) == 0 do
            {solver, true, success}
          else
            {:symbol, type, _} = entering = Row.any_pivotable_symbol(rowptr)

            if type == :invalid do
              {solver, true, false}
            else
              rowptr = Row.solve_for(rowptr, art, entering)
              solver = substitute(solver, entering, rowptr)
              solver = %Solver{solver | rows: Map.put(solver.rows, entering, rowptr)}
              {solver, false, nil}
            end
          end

        nil ->
          {solver, false, nil}
      end

    if return == true do
      {solver, val}
    else
      solver = %Solver{
        solver
        | rows:
            solver.rows
            |> Enum.map(fn {s, r} -> {s, Row.remove(r, art)} end)
            |> Enum.into(%{}),
          objective: Row.remove(solver.objective, art)
      }

      {solver, success}
    end
  end

  defp insert_into_objective(
         %Solver{objective: objective} = solver,
         {:symbol, _, _} = symbol,
         coefficient
       ) do
    %Solver{solver | objective: Row.insert(objective, symbol, coefficient)}
  end

  def remove_constraint(%Solver{} = solver, {:constraint, _, _} = constraint) do
    case Map.get(solver.cns, constraint) do
      nil ->
        raise "Unknown constraint."

      {:tag, marker, _} = tag ->
        solver = %Solver{solver | cns: Map.delete(solver.cns, constraint)}
        strength = Map.get(solver.strengths, constraint)
        solver = %Solver{solver | strengths: Map.delete(solver.strengths, constraint)}
        solver = remove_constraint_effects(solver, tag, strength)

        solver =
          case Map.get(solver.rows, marker) do
            %Row{} ->
              %Solver{solver | rows: Map.delete(solver.rows, marker)}

            nil ->
              row = get_marker_leaving_row(solver, marker)

              if row == nil do
                raise "Internal solver error."
              end

              leaving =
                solver.rows
                |> Enum.find(fn {_key, r} -> r == row end)
                |> elem(0)

              if leaving == nil do
                raise "Internal solver error."
              end

              solver = %Solver{solver | rows: Map.delete(solver.rows, leaving)}
              row = Row.solve_for(row, leaving, marker)
              solver = substitute(solver, marker, row)
              solver
          end

        optimize(solver, solver.objective)
    end
  end

  defp remove_constraint_effects(
         %Solver{} = solver,
         {:tag, {:symbol, :error, _} = marker, _} = _tag,
         strength
       ),
       do: remove_marker_effects(solver, marker, strength)

  defp remove_constraint_effects(
         %Solver{} = solver,
         {:tag, _, {:symbol, :error, _} = other} = _tag,
         strength
       ),
       do: remove_marker_effects(solver, other, strength)

  defp remove_constraint_effects(%Solver{} = solver, {:tag, _, _} = _tag, _strength), do: solver

  defp remove_marker_effects(%Solver{rows: rows} = solver, {:symbol, _, _} = marker, strength)
       when is_number(strength) do
    case Map.get(rows, marker) do
      %Row{} = row ->
        insert_into_objective(solver, row, -strength)

      nil ->
        insert_into_objective(solver, marker, -strength)
    end
  end

  defp get_marker_leaving_row(%Solver{rows: rows}, {:symbol, _, _} = marker) do
    {_r1, _r2, first, second, third} =
      Enum.reduce(rows, {nil, nil, nil, nil, nil}, fn {{:symbol, type, _} = _key,
                                                       %Row{} = candidate_row},
                                                      {r1, r2, first, second, third} = acc ->
        c = Row.coefficient_for(candidate_row, marker)

        if c == 0 do
          acc
        else
          if type == :external do
            {r1, r2, first, second, candidate_row}
          else
            if c < 0 do
              r = -candidate_row.constant / c

              if r < r1 do
                {r, r2, candidate_row, second, third}
              else
                acc
              end
            else
              r = candidate_row.constant / c

              if r < r2 do
                {r1, r, first, candidate_row, third}
              else
                acc
              end
            end
          end
        end
      end)

    first || second || third
  end

  def add_edit_variable(%Solver{} = solver, var, :strong) when is_reference(var),
    do: add_edit_variable(solver, var, Strength.strong())

  def add_edit_variable(%Solver{} = solver, var, :medium) when is_reference(var),
    do: add_edit_variable(solver, var, Strength.medium())

  def add_edit_variable(%Solver{} = solver, var, :weak) when is_reference(var),
    do: add_edit_variable(solver, var, Strength.weak())

  def add_edit_variable(%Solver{} = solver, var, {:strength, _} = strength)
      when is_reference(var) do
    if Map.has_key?(solver.edits, var) do
      raise "Duplicate edit variable."
    end

    strength = Strength.clip(strength)

    if !Strength.weaker_than?(strength, Strength.required()) do
      raise "Edit variable must be weaker than :required."
    end

    constraint = {:constraint, {:expression, [{:term, var, 1}], 0}, :eq}
    solver = add_constraint(solver, constraint, strength)

    %Solver{
      solver
      | edits:
          Map.put(solver.edits, var, {:edit_info, constraint, Map.get(solver.cns, constraint), 0})
    }
  end

  def remove_edit_variable(%Solver{} = solver, var) when is_reference(var) do
    case Map.get(solver.edits, var) do
      nil ->
        raise "Unknown edit variable."

      {:edit_info, constraint, _tag, _constant} ->
        solver = remove_constraint(solver, constraint)
        %Solver{solver | edits: Map.delete(solver.edits, var)}
    end
  end

  def suggest_value(%Solver{} = solver, var, value) when is_reference(var) and is_number(value) do
    case Map.get(solver.edits, var) do
      nil ->
        raise "Unknown edit variable."

      {:edit_info, constraint, {:tag, marker, other} = tag, constant} ->
        delta = value - constant

        solver = %Solver{
          solver
          | edits: Map.put(solver.edits, var, {:edit_info, constraint, tag, value})
        }

        {row, sym} =
          if row?(solver, marker) != nil do
            {row?(solver, marker), marker}
          else
            if row?(solver, other) != nil do
              {row?(solver, other), other}
            else
              {nil, nil}
            end
          end

        if row != nil do
          row = Row.add(row, -delta)
          solver = %Solver{solver | rows: Map.put(solver.rows, sym, row)}

          solver =
            if row.constant < 0 do
              %Solver{solver | infeasible_rows: [sym | solver.infeasible_rows]}
            else
              solver
            end

          dual_optimize(solver)
        else
          solver =
            solver.rows
            |> Enum.reduce(solver, fn {{:symbol, type, _} = sym, r}, solver ->
              coefficient = Row.coefficient_for(r, marker)
              r = Row.add(r, delta * coefficient)
              solver = %Solver{solver | rows: Map.put(solver.rows, sym, r)}

              if coefficient != 0 and r.constant < 0 and type != :external do
                %Solver{solver | infeasible_rows: [sym | solver.infeasible_rows]}
              else
                solver
              end
            end)

          dual_optimize(solver)
        end
    end
  end

  defp dual_optimize(%Solver{} = solver) do
    if length(solver.infeasible_rows) == 0 do
      solver
    else
      [leaving | infeasible] = solver.infeasible_rows

      case row?(solver, leaving) do
        %Row{constant: constant} = row when constant < 0 ->
          solver = %Solver{solver | infeasible_rows: infeasible}
          {:symbol, type, _} = entering = get_dual_entering_symbol(solver, row)

          if type == :invalid do
            raise "Internal solver error."
          end

          solver = %Solver{solver | rows: Map.delete(solver.rows, leaving)}
          row = Row.solve_for(row, leaving, entering)
          solver = substitute(solver, entering, row)
          solver = %Solver{solver | rows: Map.put(solver.rows, entering, row)}
          dual_optimize(solver)

        _ ->
          %Solver{solver | infeasible_rows: infeasible}
      end
    end
  end

  defp get_dual_entering_symbol(%Solver{} = solver, %Row{} = row) do
    row.cells
    |> Enum.reduce({Symbol.invalid(), nil}, fn {{:symbol, type, _} = symbol, coefficient},
                                               {_entering, ratio} = best ->
      if type != :dummy and coefficient > 0 do
        candidate_ratio = Row.coefficient_for(solver.objective, symbol) / coefficient

        if ratio == nil or candidate_ratio < ratio do
          {symbol, candidate_ratio}
        else
          best
        end
      else
        best
      end
    end)
    |> elem(0)
  end

  defp row?(%Solver{rows: rows}, {:symbol, _, _} = symbol), do: Map.get(rows, symbol)

  defp var_symbol?(%Solver{vars: vars} = solver, var) when is_reference(var) do
    case Map.get(vars, var) do
      {:symbol, _, _} = sym ->
        {solver, sym}

      nil ->
        sym = Symbol.external()
        {%Solver{solver | vars: Map.put(vars, var, sym)}, sym}
    end
  end

  def value?(%Solver{} = solver, var) when is_reference(var) do
    case Map.get(solver.vars, var) do
      {:symbol, _, _} = symbol ->
        case Map.get(solver.rows, symbol) do
          %Row{} = row -> row.constant
          _ -> 0
        end

      nil ->
        0
    end
  end
end
