# Mapper2

Mapper2 is a general place-and-route framework. It allows for heterogenous 
mapping to arbitrary-dimensional architectural models. Features of this package
include:

* Types and constructors for heterogenous many-core processors.
* User-defined semantics for placement and routing with generic fallbacks, 
    allowing the user to customize these algorithms for their architecture.
* Extensibility in algorithms for implementing new placement and routing 
    techniques.

# Installation

This package may be installed from the Julia REPL using the command:

```julia
Pkg.clone("https://github.com/hildebrandmw/Mapper2.jl")
```

# RuleSet Types

Much of the behavior of this module can be affected by defining a custom subtype
of [`RuleSet`](@ref) and extending various methods.

```@docs
MapperCore.RuleSet
```
