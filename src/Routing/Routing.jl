#=
Root file for the routing related files.
=#

module Routing

using ..Mapper2: Addresses, Helper, Taskgraphs, Architecture, MapType, Debug
using DataStructures
using LightGraphs

export route

abstract type AbstractRoutingLink end
const ARL = AbstractRoutingLink

# Abstract super types for all link annotators.
abstract type AbstractLinkAnnotator end
const ANA = AbstractLinkAnnotator

abstract type AbstractRoutingAlgorithm end


# This file converts the top level architecture to a simple graph plus
# translation dictionaries.
include("RoutingGraph.jl")
include("LinkAnnotations.jl")
include("RoutingTaskgraph.jl")
# Encapsulation for the whole routing struct.
include("RoutingStruct.jl")

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


#------------------#
# Link Annotations #
#------------------#

"""
    empty_annotator(::Type{A}, rg::RoutingGraph) where A <: AbstractArchitecture

Return an empty `DefaultLinkAnnotator()` for this architecture and routing graph.
Specialized implementations may alter the type of the annotator returned.
"""
function empty_annotator(::Type{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    links = Vector{DefaultRoutingLink}(nv(rg.graph))
    return DefaultLinkAnnotator(links)
end

"""
    annotate_port( ::Type{A}, annotator::B, ports, link_index) where 
    A <: AbstractArchitecture, 
    B <: AbstractLinkAnnotator

Add an entry to `annotator` for the architecture link at `link_index`. Ports
given may be a collection of ports. Default implementation inserts a
`DefaultRoutingLink()` into the DefaultLinkAnnotator.

Specialized types may return different subtypes of AbstractRoutingLink or
modify the Link Annotator entirely.
""" 
function annotate_port(
        ::Type{A}, 
        annotator::B, 
        ports,      # Single or collection of Port types 
        link_index) where {A <: AbstractArchitecture,
                           B <: AbstractLinkAnnotator}
    annotator[link_index] = DefaultRoutingLink()
end

"""
    annotate_link( ::Type{A}, annotator::B, links, link_index) where 
    A <: AbstractArchitecture, 
    B <: AbstractLinkAnnotator

Add an entry to `annotator` for the architecture link at `link_index`. Links
given may be a collection of links. Default implementation inserts a
`DefaultRoutingLink()` into the DefaultLinkAnnotator.

Specialized types may return different subtypes of AbstractRoutingLink or
modify the Link Annotator entirely.
""" 
function annotate_link(
        ::Type{A}, 
        annotator::B, 
        links,   # Single or collection of Link types
        link_index) where {A <: AbstractArchitecture, B <: AbstractLinkAnnotator}
    annotator[link_index] = DefaultRoutingLink()
end


"""
    canuse(::Type{A}, rs::RoutingStruct, arch_link::Integer, task_link::Integer) where A <: AbstractArchitecture

Indicate whether the architecture link at `arch_link` can be used by the
taskgraph link at `task_link`. Default implementation always returns true.

Specialized implementations can allow for multiple, separate networks.
"""
function canuse(::Type{A}, 
                rs::RoutingStruct, 
                arch_link::Integer, 
                task_link::Integer) where A <: AbstractArchitecture
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
