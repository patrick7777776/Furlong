# Furlong

Furlong is an Elixir port of the [Kiwi Solver](https://kiwisolver.readthedocs.io/en/latest/basis/basic_systems.html).
More accurately, Furlong is a port of [Kiwi Java](https://github.com/alexbirkett/kiwi-java), which itself is a port of the Kiwi Solver. The Kiwi Solver is
an implementation/evolution of the [Cassowary](http://overconstrained.io/) constraint solving toolkit for linear equalities and inequalities, 
which can be used for calculating constraint-based layouts.

Furlong provides the fundamental Kiwi Solver functionality, but does not include any other conveniences.

## Installation

Add `furlong` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:furlong, "~> 0.1.0"}
  ]
end
```


## Example

A 2d box can be represented by the x-coordinates of its left and right side as well as the y-coordinates of its top and bottom.  For the sake of simplicity, I will omit the y-axis,
leaving us with two variables, left and right, to represent an example box. Furlong uses Erlang references to identify variables. 

```
iex(1)> b1_l = make_ref() # box 1, x-coordinate of left side
#Reference<0.3137981872.1258029059.84356>
iex(2)> b1_r = make_ref() # box 1, x-coordinate of right side
#Reference<0.3137981872.1258029059.84375>
```

The core part of Furlong is the Solver, which maintains a system of constraints.

```
iex(3)> import Furlong.Solver
iex(4)> system = new()
```

We can now add to our system some simple constraints. For example, that our box be at least ten units wide.
Currently, the constraints need to be specified via the functions in Furlong.Symbolics. In the future, I might add a macro that allows one to write constraints more naturally.

```
iex(5)> import Furlong.Symbolics
iex(6)> w1 = make_ref # width of box 1
iex(7)> system =
...(7)> system |>
...(7)> add_constraint(eq(w1, subtract(b1_r, b1_l))) |> # box 1's width = right - left
...(7)> add_constraint(gte(w1, 10))                     # box 1 width must be at least 10 units
```

Let's assume that we have a drawing area of size max_x * max_y units. Our box is to be placed inside this area:

```
iex(8)> maxx = make_ref()
iex(9)> system =
...(9)> system |>
...(9)> add_constraint(gte(b1_l, 0)) |>
...(9)> add_constraint(lte(b1_r, maxx))
```

Let's set maxx to 640 units:

```
iex(11)> system = add_constraint(system, eq(maxx, 640))
```

Let's find out where the example box has been placed by the solver:

```
iex(11)> value?(system, b1_l)
0.0
iex(12)> value?(system, b1_r)
640.0
```

The solver made our box as big as the drawing area, which is a fine solution, indeed.

Let's add in another box to the right of our first box, with at least a certain amount of space in between and let's demand that the second box have exactly the same width as the first one:

```
iex(13)> b2_l = make_ref()
iex(14)> b2_r = make_ref()
iex(15)> w2 = make_ref()
iex(16)> spacer = make_ref()

iex(17)> system =
...(17)> system |>
...(17)> add_constraint(gte(b2_l, add(b1_r, spacer))) |>
...(17)> add_constraint(lte(b2_r, maxx)) |>
...(17)> add_constraint(eq(w2, subtract(b2_r, b2_l))) |>
...(17)> add_constraint(eq(w1, w2)) |>
...(17)> add_constraint(lte(spacer, divide(maxx, 10))) |>
...(17)> add_constraint(gte(spacer, divide(maxx, 20)))

iex(18)> {{value?(system, b1_l), value?(system, b1_r)}, {value?(system, b2_l), value?(system, b2_r)}}
{{588.0, 598.0}, {630.0, 640.0}}
```

Both boxes have the same width and box 2 is to the right of box 1. If we wanted a more asthetically pleasing positioning, we could for example demand that the width of the drawing area be fully used up by the boxes and the spacer:

```
iex(19)> system = add_constraint(system, eq(add(add(w1, w2), spacer), maxx))

iex(20)> {{value?(system, b1_l), value?(system, b1_r)}, {value?(system, b2_l), value?(system, b2_r)}}
{{0.0, 304.0}, {336.0, 640.0}}
```

Finally, let's make the drawing area resizable:

```
iex(21)> system =
...(21)> system |>
...(21)> remove_constraint(eq(maxx, 640)) |>
...(21)> add_edit_variable(maxx, :strong) |>
...(21)> suggest_value(maxx, 1000)

iex(22)> {{value?(system, b1_l), value?(system, b1_r)}, {value?(system, b2_l), value?(system, b2_r)}}
{{0.0, 475.0}, {525.0, 1000}}

iex(23)> system = suggest_value(system, maxx, 240)
iex(24)> {{value?(system, b1_l), value?(system, b1_r)}, {value?(system, b2_l), value?(system, b2_r)}}
{{0.0, 114.0}, {126.0, 240.0}}
```

