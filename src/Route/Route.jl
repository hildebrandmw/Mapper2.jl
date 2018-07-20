#=
Root file for the routing related files.
=#

module Routing

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using ..Mapper2.MapperGraphs

using DataStructures

using Logging
using Random

export  route,
        RoutingStruct,
        AbstractRoutingLink,
        RoutingLink,
        AbstractRoutingChannel,
        RoutingChannel,
        routing_link_type,
        routing_channel,
        annotate

abstract type AbstractRoutingLink end
abstract type AbstractRoutingChannel end
abstract type AbstractRoutingAlgorithm end

const AA = Architecture
const ARL = AbstractRoutingLink
const ARC = AbstractRoutingChannel

@doc """
Representation of  routing resources in an architecture. Required fields:

* `channels::Vector{Int64}` - List of channels using this routing resource. Must
    initialize to empty.
* `cost::Float64` - The cost of a channel using this resource.
* `capacity::Int64` - The number of channels that can simulaneously use this 
    resouce.



More advanced implementations may contain different fields provided the following
interfaces are implemented:

""" AbstractRoutingLink

@doc """
Representation of channels in the taskgraph for routing. Required fields:

* `start::Vector{Vector{Int64}}` - Collection of start vertices for each start
    node of the channel.
* `stop::Vector{Vector{Int64}}` - Collection of stop vertices for each stop 
    node of the channel.



More advanced implementations may contain different fields provided the following
interfaces are implemented:

""" AbstractRoutingChannel

################################################################################
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
    try
        _, route_time, route_bytes, _, _ = @timed route(algorithm, routing_struct)
    catch err
        @error err
        routing_error = true
    end

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

Return some `<:AbstractRoutingLink` for `item`. See [`AbstractRoutingLink`](@ref)
for required fields. If `item <: Component`, it is a primitive. If not other 
primitives have been defined, it will be a `mux`.
"""
function annotate(::Type{A}, item::Union{Port,Link,Component}) where A <: AA
    RoutingLink(capacity = getcapacity(A, item))
end

"""
    canuse(::Type{<:Architecture}, item::AbstractRoutingLink, channel::AbstractRoutingChannel)

Return `true` if `channel` can be routed using `item`.

See: [`AbstractRoutingLink`](@ref), [`AbstractRoutingChannel`](@ref)
"""
MapperCore.canuse(::Type{A}, item::ARL, channel::ARC) where A <: AA = true

end
