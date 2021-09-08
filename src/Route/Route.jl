#=
Root file for the routing related files.
=#

module Routing

using ..Mapper2.Helper
Helper.@SetupDocStringTemplates

using ..Mapper2.MapperCore
using ..Mapper2.MapperGraphs

using DataStructures

using Logging
using Random

export route!,
    ChannelIndex,
    PortVertices,
    RoutingStruct,
    RoutingLink,
    BasicRoutingLink,
    RoutingChannel,
    BasicRoutingChannel,
    routing_link_type,
    routing_channel,
    annotate

abstract type AbstractRoutingAlgorithm end

"""
Representation of routing resources in an architecture.

API
---
* [`channels`](@ref)
* [`cost`](@ref)
* [`capacity`](@ref)
* [`occupancy`](@ref)
* [`addchannel`](@ref)
* [`remchannel`](@ref)

Implementations
---------------
* [`BasicRoutingLink`](@ref) - Reference this type for what methods of the API
    come for free when using various fields of the basic type.
"""
abstract type RoutingLink end

"""
Representation of channels in the taskgraph for routing.

API
---
* [`start_vertices`](@ref)
* [`stop_vertices`](@ref)
* [`isless(a::RoutingChannel, b::RoutingChannel)`](@ref)

Implementations
---------------
* [`BasicChannel`](@ref)
"""
abstract type RoutingChannel end

################################################################################
include("Types.jl")
include("Graph.jl")
include("Links.jl")
include("Channels.jl")
include("Struct.jl")

# Algorithms
include("Pathfinder/Pathfinder.jl")

# Routing dispatch
"""
    route!(map::Map; meta_prefix = "")

Run pathfinder routing directly on `map`. Keyword argument `meta_prefix` allows
controlling the prefix of the `map.metadata` keys generated below.

Records the following metrics into `map.metadata`:

* `routing_struct_time` - Time it took to build the [`RoutingStruct`](@ref)

* `routing_struct_bytes` - Memory allocation to build [`RoutingStruct`](@ref)

* `routing_passed :: Bool` - `true` if routing passes [`check_routing`](@ref),
    otherwise `false`.
    
* `routing_error :: Bool` - `true` if routing experienced a connectivity error.

The following are also included if `routing_error == false`.

* `routing_time` - Time to run routing.

* `routing_bytes` - Memory allocation during routing.

* `routing_global_links` - The number of global links used in the final routing.
"""
function route!(m::Map; meta_prefix = "")
    # Build the routing structure
    routing_struct, struct_time, struct_bytes, _, _ = @timed RoutingStruct(m)
    # Default to Pathfinder
    algorithm = routing_algorithm(m, routing_struct)
    # Run the routing algorithm.
    routing_error = false
    local route_time
    local route_bytes
    try
        _, route_time, route_bytes, _, _ = @timed route!(algorithm, routing_struct)
    catch err
        @error err
        routing_error = true
    end

    # Record the final results.
    record(m, routing_struct)
    routing_passed = check_routing(m)

    # Save all of this to metadata.
    m.metadata["$(meta_prefix)routing_struct_time"] = struct_time
    m.metadata["$(meta_prefix)routing_struct_bytes"] = struct_bytes
    m.metadata["$(meta_prefix)routing_passed"] = routing_passed
    m.metadata["$(meta_prefix)routing_error"] = routing_error
    if !routing_error
        m.metadata["$(meta_prefix)routing_time"] = route_time
        m.metadata["$(meta_prefix)routing_bytes"] = route_bytes
        m.metadata["$(meta_prefix)routing_global_links"] = MapperCore.total_global_links(m)
    end

    return nothing
end

routing_algorithm(m::Map, rs) = Pathfinder(m, rs)

################################################################################
# REQUIRED METHODS
################################################################################
"""
    annotate(ruleset::RuleSet, item::Union{Port,Link,Component})

Return some [`<:RoutingLink`](@ref RoutingLink) for `item`.  If 
`item <: Component`, it is a primitive. If not other primitives have been 
defined, it will be a `mux`.

See: [`BasicRoutingLink`](@ref)

Default: `BasicRoutingLink(capacity = getcapacity(ruleset, item))
"""
function annotate(ruleset::RuleSet, item::Union{Port,Link,Component})
    return BasicRoutingLink(; capacity = getcapacity(ruleset, item))
end

"""
    canuse(ruleset::RuleSet, link::RoutingLink, channel::RoutingChannel)::Bool

Return `true` if `channel` can be routed using `link`.

See: [`RoutingLink`](@ref), [`RoutingChannel`](@ref)

Default: `true`
"""
MapperCore.canuse(::RuleSet, link::RoutingLink, channel::RoutingChannel) = true

end
