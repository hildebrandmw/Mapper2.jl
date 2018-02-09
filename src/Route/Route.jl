#=
Root file for the routing related files.
=#

module Routing

using ..Mapper2: Addresses, Helper, Taskgraphs, Architecture, MapType
using DataStructures
using LightGraphs
using MicroLogging

export  route,
        RoutingStruct,
        AbstractRoutingLink,
        RoutingLink,
        AbstractRoutingChannel,
        RoutingChannel,
        ChannelList,
        routing_link_type,
        routing_channel_type,
        annotate_port,
        annotate_link,
        annotate_component,
        canuse,
        isvalid_source_port,
        isvalid_sink_port

abstract type AbstractRoutingLink end
abstract type AbstractRoutingChannel end
abstract type AbstractRoutingAlgorithm end



# This file converts the top level architecture to a simple graph plus
# translation dictionaries.
include("Graph.jl")
include("Links.jl")
include("Channels.jl")
# Encapsulation for the whole routing struct.
include("Struct.jl")

# Algorithms
include("Pathfinder.jl")

# Verification
include("Verification.jl")

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

function routing_algorithm(m::Map{A,D}, rs) where {A <: AbstractArchitecture, D}
    return Pathfinder(m, rs)
end

################################################################################
# REQUIRED METHODS
################################################################################

routing_link_type(::Type{A}) where {A <: AbstractArchitecture} = RoutingLink
routing_channel_type(::Type{A}) where {A <: AbstractArchitecture} = RoutingChannel

function annotate_port(::Type{A}, port) where {A <: AbstractArchitecture}
    return RoutingLink()
end

function annotate_link(::Type{A}, link) where {A <: AbstractArchitecture}
    return RoutingLink()
end

function annotate_component(::Type{A}, component::Component, ports) where {A <: AbstractArchitecture}
    @assert component.primitive == "mux"
    return RoutingLink()
end


"""
    canuse(::Type{A}, rs::RoutingStruct, arch_link::Integer, task_link::Integer) where A <: AbstractArchitecture

Indicate whether the architecture link at `arch_link` can be used by the
taskgraph link at `task_link`. Default implementation always returns true.

Specialized implementations can allow for multiple, separate networks.
"""
function canuse(::Type{A},link::AbstractRoutingLink,task::AbstractRoutingChannel) where
        A <: AbstractArchitecture
    return true
end

function canuse(::Type{A}, item::Union{Port,Link}, edge::TaskgraphEdge) where 
        A <: AbstractArchitecture
    return true
end


"""
    isvalid_source_port(::Type{A}, port::Port, edge::TaskgraphEdge) where A <: AbstractArchitecture

Return `true` if `port` is a valid source for taskgraph `edge`.
"""
function isvalid_source_port(::Type{A}, port::Port, edge::TaskgraphEdge) where A <: AbstractArchitecture
    return port.class in PORT_SINKS
end

"""
    isvalid_sink_port(::Type{A}, port::Port, edge::TaskgraphEdge) where A <: AbstractArchitecture

Return `true` if `port` is a valid sink for taskgraph `edge`.
"""
function isvalid_sink_port(::Type{A}, port::Port, edge::TaskgraphEdge) where
        A <: AbstractArchitecture
    return port.class in PORT_SOURCES
end

end
