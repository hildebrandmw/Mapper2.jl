module MapperCore

using ..Mapper2.Helper
using IterTools
using JSON
using DataStructures
using MicroLogging
using ProgressMeter
using LightGraphs

emptymeta() = Dict{String,Any}()

include("Taskgraphs.jl")
include("Architecture/Architecture.jl")
include("Map/Map.jl")

### Taskgraph Exports###

export  # Types
        TaskgraphNode,
        TaskgraphEdge,
        Taskgraph,
        # Methods
        getsources,
        getsinks,
        getnodes,
        getedges,
        getnode,
        getedge,
        nodenames,
        num_nodes,
        num_edges,
        add_node,
        add_edge,
        out_edges,
        in_edges,
        hasnode,
        out_nodes

### Architecture Exports ###
export  AbstractArchitecture,
        # Path Types
        AbstractPath,
        AbstractComponentPath,
        ComponentPath,
        AddressPath,
        PortPath,
        LinkPath,
        # Path Methods
        istop,
        prefix,
        push,
        pushfirst,
        typestring,
        # Architecture stuff
        AbstractPort,
        Port,
        Link,
        PORT_SINKS,
        PORT_SOURCES,
        # Link Methods
        isaddresslink,
        # Components
        AbstractComponent,
        TopLevel,
        Component,
        # Methods
        ports,
        architecture,
        addresses,
        pathtype,
        children,
        walk_children,
        connected_components,
        search_metadata,
        search_metadata!,
        check_connectivity,
        get_connected_port,
        isfree,
        isgloballink,
        isglobalport,
        # Asserts
        assert_no_children,
        assert_no_intrarouting,
        # Constructor Types
        OffsetRule,
        PortRule,
        # Constructor Functions
        add_port,
        add_child,
        add_link,
        connection_rule,
        build_mux,
        check,
        # Methods
        build_distance_table,
        build_component_table

### Map ###
export  Map,
        Mapping,
        NewMap,
        NodeMap,
        EdgeMap,
        save,
        load


export  isspecial,
        isequivalent,
        ismappable, 
        canmap,
        canuse,
        isvalid_sink_port,
        isvalid_source_port,
        getcapacity

const AA = AbstractArchitecture
const TN = TaskgraphNode
const TE = TaskgraphEdge
const PLC = Union{Port,Link,Component}

# Placement Queries
isspecial(::Type{T}, t::TN) where {T <: AA}             = false
isequivalent(::Type{T}, a::TN, b::TN) where {T <: AA}   = true
ismappable(::Type{T}, c::Component) where {T <: AA}     = true
canmap(::Type{T}, t::TN, c::Component) where {T <: AA}  = true 

# Routing Queries
canuse(::Type{<:AA},item::PLC, edge::TE)                = true
getcapacity(::Type{A}, item::PLC) where A <: AA         = 1

isvalid_source_port(::Type{<:AA}, port::Port, edge::TE) = (port.class in PORT_SINKS)
isvalid_sink_port(::Type{<:AA}, port::Port, edge::TE) = (port.class in PORT_SOURCES)

end
