# Move Generators

Move generators (believe it or not) generate moves in the inner loop of simulated
annealing placement. Move generators must subtype from `AbstractMoveGenerator`
and have the following API:

```@index
Pages = ["MoveGenerators.md"]
```

```@docs
SA.generate_move
SA.distancelimit
SA.initialize!
SA.update!
```

# Implementations

## Search Move Generator

```@docs
SA.SearchMoveGenerator
```

## Cached Move Generator

```@docs
SA.CachedMoveGenerator
SA.MoveLUT
```
