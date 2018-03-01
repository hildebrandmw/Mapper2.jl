#=
Root file for the routing related files.
=#

module Routing

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using DataStructures
using LightGraphs
using MicroLogging

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

# This file converts the top level architecture to a simple graph plus
# translation dictionaries.
include("Graph.jl")
include("Links.jl")
include("Channels.jl")

# Encapsulation for the whole routing struct.
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
    return m
end

routing_algorithm(m::Map{A,D}, rs) where {A <: AA, D} = Pathfinder(m, rs)

################################################################################
# REQUIRED METHODS
################################################################################
function annotate(::Type{A}, item::Union{Port,Link,Component}) where A <: AA
    RoutingLink(capacity = getcapacity(A, item))
end

MapperCore.canuse(::Type{A}, item::ARL, edge::ARC) where A <: AA = true

end
