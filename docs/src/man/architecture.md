# Data Types

Mapper2 allows hierarchical modeling of architectures. The top level datatype
is the `TopLevel` struct. Submodules of this type are of type `Component` and
are keyed by a `CartesianIndex` that denotes its location in the architecture. 

The `Component` type may have `Component` submodules that are accessed by a 
string instance id. `Components` may also have `Ports` and `Links` that connect
ports together.

```@meta
DocTestSetup = quote
    using Mapper2
end
```

## AbstractArchitecture
```@docs
AbstractArchitecture
```

## TopLevel
```@docs
TopLevel
```

## Component
```@docs
Component
```

## Port
```@docs
Port
```

## Link
```@docs
Link
```
