# Introduction

Furlong is an Elixir port of the [Kiwi Solver](https://kiwisolver.readthedocs.io/en/latest/basis/basic_systems.html).
More accurately, Furlong is a port of [Kiwi Java](https://github.com/alexbirkett/kiwi-java), which itself is a port of the Kiwi Solver. The Kiwi Solver is
an implementation/evolution of the [Cassowary](http://overconstrained.io/) constraint solving toolkit for linear equalities and inequalities, 
which can be used for calculating constraint-based layouts.

Furlong provides the fundamental Kiwi Solver functionality, but does not include any other conveniences.

The main point of interaction is the `Furlong.Solver` module; see its documentation for a usage example.
