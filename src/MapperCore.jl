module MapperCore

const is07 = VERSION > v"0.7.0-"

using ..Mapper2.Helper
using IterTools
using DataStructures
using Compat

is07 ? (using Logging) : (using MicroLogging)
is07 && (using Serialization)

using LightGraphs

const _arch_types = (
        :AbstractArchitecture,
        :TopLevel,
        :Component,
        :Port,
        :Link,
    )

const _toplevel_constructions = (
        :add_child, 
        :add_link, 
        :connection_rule
    )

const _toplevel_analysis = (
        :walk_children,
        :connected_components,
        :search_metadata,
        :search_metadata!,
        :check,
        :build_distance_table,
        :build_neighbor_table,
        :connectedlink,
        :connectedports,
        :isconnected
    )

include("Taskgraphs.jl")

# Architecture includes
include("Architecture/Paths.jl")
include("Architecture/Architecture.jl")
include("Architecture/Methods.jl")
include("Architecture/Constructors.jl")

# Map Includes
include("Map/Map.jl")
include("Map/Verification.jl")
include("Map/Inspection.jl")

#-------------------------------------------------------------------------------
# Mapping methods
#-------------------------------------------------------------------------------
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
canuse(::Type{<:AA}, item::PLC, edge::TE)               = true
getcapacity(::Type{A}, item) where A <: AA              = 1

is_source_port(::Type{<:AA}, port::Port, edge::TE)      = true
is_sink_port(::Type{<:AA}, port::Port, edge::TE)        = true
needsrouting(::Type{A}, edge::TE) where A <: AA         = true


#-------------------------------------------------------------------------------
# Exports
#-------------------------------------------------------------------------------

export  isspecial,
        isequivalent,
        ismappable, 
        canmap,
        canuse,
        is_sink_port,
        is_source_port,
        getcapacity,
        needsrouting

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
        getoffset,
        getdims,
        nodenames,
        num_nodes,
        num_edges,
        add_node,
        add_edge,
        out_edges,
        out_edge_indices,
        in_edges,
        in_edge_indices,
        hasnode,
        outnode_names,
        innode_names,
        out_nodes,
        in_nodes,

        ### Architecture Exports ###
        AbstractArchitecture,
        # Path Types
        AbstractPath,
        Path,
        AddressPath,
        catpath,
        striplast,
        splitpath,
        stripfirst,

        # Architecture stuff
        Port,
        Link,
        # Port Methods
        invert,
        # Link Methods
        isaddresslink,
        sources,
        dests,
        # Components
        AbstractComponent,
        TopLevel,
        Component,
        @port_str,
        @link_str,
        @component_str,
        # Verification
        check_routing,
        # Methods
        checkclass,
        ports,
        portnames,
        addresses,
        pathtype,
        children,
        walk_children,
        connected_components,
        search_metadata,
        search_metadata!,
        get_metadata!,
        check_connectivity,
        get_connected_port,
        isfree,
        isgloballink,
        isglobalport,
        getaddress,
        hasaddress,
        getchild,
        getname,
        mappables,
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
        ConnectionRule,
        Offset,
        # Analysis methods
        build_distance_table,
        build_component_table,

        ### Map ###
        Map,
        Mapping,
        NewMap,
        NodeMap,
        EdgeMap,
        save,
        load
end
