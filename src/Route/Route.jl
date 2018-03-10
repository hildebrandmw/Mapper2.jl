#=
Root file for the routing related files.
=#

module Routing

const is07 = VERSION > v"0.7.0-"

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using DataStructures
using LightGraphs
using Compat

is07 ? (using Logging) : (using MicroLogging)
is07 && (using Random)

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

const AA = AbstractArchitecture
const ARL = AbstractRoutingLink
const ARC = AbstractRoutingChannel

const _arl_interface = (:channels, 
                        :cost, 
                        :capacity, 
                        :occupancy, 
                        :iscongested,
                        :remchannel, 
                        :addchannel,
                       )
const _arl_default      = (:RoutingLink,)
const _arl_constructor  = (:annotate,)

const _arc_interface = (:start, :stop, :isless)
const _arc_default   = (:RoutingChannel,)
const _arc_constructor = (:routing_channel,)

@doc """
Representation of  routing resources in an architecture. Required fields:

* `channels::Vector{Int64}` - List of channels using this routing resource. Must
    initialize to empty.
* `cost::Float64` - The cost of a channel using this resource.
* `capacity::Int64` - The number of channels that can simulaneously use this 
    resouce.

Default implementation: $(make_ref_list(_arl_default))

Overload constructor: $(make_ref_list(_arl_constructor))

More advanced implementations may contain different fields provided the following
interfaces are implemented:

$(make_ref_list(_arl_interface))
""" AbstractRoutingLink

@doc """
Representation of channels in the taskgraph for routing. Required fields:

* `start::Vector{Vector{Int64}}` - Collection of start vertices for each start
    node of the channel.
* `stop::Vector{Vector{Int64}}` - Collection of stop vertices for each stop 
    node of the channel.

Default implementation: $(make_ref_list(_arc_default))

Overload constructor: $(make_ref_list(_arc_constructor))

More advanced implementations may contain different fields provided the following
interfaces are implemented:

$(make_ref_list(_arc_interface))
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
    routing_struct = RoutingStruct(m)
    # Default to Pathfinder
    algorithm = routing_algorithm(m, routing_struct)
    # Run the routing algorithm.
    route(algorithm, routing_struct)
    # Record the final results.
    record(m, routing_struct)
    check_routing(m)
    return m
end

routing_algorithm(m::Map{A,D}, rs) where {A <: AA, D} = Pathfinder(m, rs)

################################################################################
# REQUIRED METHODS
################################################################################
"""
    annotate(::Type{<:AbstractArchitecture}, item::Union{Port,Link,Component})

Return some `<:AbstractRoutingLink` for `item`. See [`AbstractRoutingLink`](@ref)
for required fields. If `item <: Component`, it is a primitive. If not other 
primitives have been defined, it will be a `mux`.
"""
function annotate(::Type{A}, item::Union{Port,Link,Component}) where A <: AA
    RoutingLink(capacity = getcapacity(A, item))
end

"""
    canuse(::Type{<:AbstractArchitecture}, item::AbstractRoutingLink, channel::AbstractRoutingChannel)

Return `true` if `channel` can be routed using `item`.

See: [`AbstractRoutingLink`](@ref), [`AbstractRoutingChannel`](@ref)
"""
MapperCore.canuse(::Type{A}, item::ARL, channel::ARC) where A <: AA = true

end
