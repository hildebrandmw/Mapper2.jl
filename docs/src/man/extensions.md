# Extensions

The Mapper framework is designed to alter behavior mapping behavior using
a certain set of core functions that are extended as needed for new subtypes of
[`RuleSet`](@ref). These methods only need to be extended if the default
behavior is not sufficient.

In addition, placement and routing have types and methods that can be extended
as well to more finely tune mapping.

```@docs
MapperCore.isspecial
MapperCore.isequivalent
MapperCore.ismappable
MapperCore.canmap
MapperCore.canuse
MapperCore.getcapacity
MapperCore.is_source_port
MapperCore.is_sink_port
MapperCore.needsrouting
Routing.annotate
```
