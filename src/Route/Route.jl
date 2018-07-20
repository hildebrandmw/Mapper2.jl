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

export  route,
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

const AA = Architecture

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
function route(m::Map{A,D}) where {A,D}
    # Build the routing structure
    routing_struct, struct_time, struct_bytes, _, _  = @timed RoutingStruct(m)
    # Default to Pathfinder
    algorithm = routing_algorithm(m, routing_struct)
    # Run the routing algorithm.
    routing_error = false
    local route_time
    local route_bytes
    # try
        _, route_time, route_bytes, _, _ = @timed route(algorithm, routing_struct)
    # catch err
    #     @error err
    #     routing_error = true
    # end

    # Record the final results.
    record(m, routing_struct)
    routing_passed = check_routing(m)

    # Save all of this to metadata.
    m.metadata["routing_struct_time"]   = struct_time
    m.metadata["routing_struct_bytes"]  = struct_bytes
    m.metadata["routing_passed"]        = routing_passed
    m.metadata["routing_error"]         = routing_error
    if !routing_error
        m.metadata["routing_time"]      = route_time
        m.metadata["routing_bytes"]     = route_bytes
        m.metadata["routing_global_links"] = MapperCore.total_global_links(m)
    end

    return m
end

routing_algorithm(m::Map{A,D}, rs) where {A <: AA, D} = Pathfinder(m, rs)

################################################################################
# REQUIRED METHODS
################################################################################
"""
    annotate(::Type{<:Architecture}, item::Union{Port,Link,Component})

Return some `<:RoutingLink` for `item`. See [`RoutingLink`](@ref)
for required fields. If `item <: Component`, it is a primitive. If not other 
primitives have been defined, it will be a `mux`.
"""
function annotate(::Type{A}, item::Union{Port,Link,Component}) where A <: AA
    BasicRoutingLink(capacity = getcapacity(A, item))
end

"""
    canuse(::Type{<:Architecture}, link::RoutingLink, channel::RoutingChannel)

Return `true` if `channel` can be routed using `link`.

See: [`RoutingLink`](@ref), [`RoutingChannel`](@ref)
"""
MapperCore.canuse(::Type{A}, link::RoutingLink, channel::RoutingChannel) where A <: AA = true

end
