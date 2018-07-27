# AbstractComponent

Architecture blocks are modelled as a subtype of `AbstractComponent`. There
are two main subtypes: [`Component`](@ref), which represents all blocks that
are not at the top level of an architecture model, and [`TopLevel`](@ref).
There is only [`TopLevel`](@ref) per architecture model.

```@docs
MapperCore.getaddress
MapperCore.check
MapperCore.children
MapperCore.getindex
MapperCore.links
MapperCore.walk_children
MapperCore.search_metadata
MapperCore.search_metadata!
MapperCore.visible_ports
```

## Component

```@docs
MapperCore.Component
```

The following methods apply only to concrete [`Component`] types:

```@docs
MapperCore.ports
MapperCore.portpaths
```

## TopLevel

```@docs
MapperCore.TopLevel
```

The following methods apply only [`TopLevel`](@ref) types:

```@docs
MapperCore.addresses
MapperCore.hasaddress
MapperCore.isaddress
MapperCore.connected_components
MapperCore.mappables
MapperCore.isconnected
```
