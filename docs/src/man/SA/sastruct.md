# SAStruct

The central data structure for simulated annealing placement is the 
[`SAStruct`](@ref). Before placement, this data type will be created from the
[`Map`](@ref) and the main loop of placement will occur using this structure.

After placement, the final location of tasks will be recorded from the 
[`SAStruct`](@ref) back into the parent [`Map`](@ref).

```@docs
SA.SAStruct
```

## Flat Architecture Optimization

In the general case, any given address in the TopLevel may have multiple
mappable components. Simulated annealing placement completely supports this 
general case. However, doing so adds overhead as the available and valid slots
within each address must be traced using Vectors, which addes extra pointer
dereferencing during placement.

If this optimization is enabled and the TopLevel structure contains only a 
single mappable component per address, the "Flat Architecture Optimization" will
be applied. Practically, this means that the locations of nodes in the
SAStruct will be tracked using `CartesianIndices` rather than `Locations`, and
some tracking vectors in the SAStruct's MapTable can be simplified to `Bool`s.

Overall, it allows for much faster placement when this optimization can be 
applied without sacrificing the generality of placement when it cannot.

## Construction Pipeline

TODO
