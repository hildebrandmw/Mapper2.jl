# Move Generators

Move generators (believe it or not) generate moves in the inner loop of simulated
annealing placement.

```@docs
SA.MoveGenerator
```

## API
```@docs
SA.generate_move
SA.distancelimit
SA.initialize!
SA.update!
```

## Implementations

### Cached Move Generator

```@docs
SA.CachedMoveGenerator
SA.MoveLUT
```

### Search Move Generator

```@docs
SA.SearchMoveGenerator
```
