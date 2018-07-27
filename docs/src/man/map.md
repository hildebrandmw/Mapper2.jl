# Map

The [`Map`](@ref) holds both a [`TopLevel`](@ref) and a [`Taskgraph`](@ref). An
additional [`Mapping`](@ref) type records how the `taskgraph` maps to the 
`toplevel`.

```@docs
MapperCore.Map
MapperCore.Mapping
```

## Verification Routines

Verify the result of placement and routing.

```@docs
MapperCore.check_routing
MapperCore.check_placement
MapperCore.check_ports
MapperCore.check_capacity
MapperCore.check_architecture_connectivity
MapperCore.check_routing_connectivity
MapperCore.check_architecture_resources
```
