module MapperCore

using ..Mapper2.Helper
Helper.@SetupDocStringTemplates

using ..Mapper2.MapperGraphs

using IterTools
using DataStructures

using Logging
using Serialization

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

const AA = Architecture
const TN = TaskgraphNode
const TE = TaskgraphEdge
const PLC = Union{Port,Link,Component}

# Placement Queries
"""
    isspecial(::Type{A}, t::TaskgraphNode) :: Bool where {A <: Architecture}

Return `true` to disable move distance contraction for `t` during placement. 

Default: `false`
"""
isspecial(::Type{<:AA}, t::TN) = false

"""
    isequivalent(::Type{A}, a::TaskgraphNode, b::TaskgraphNode) :: Bool where {A <: Architecture}

Return `true` if `TaskgraphNodes` `a` and `b` are semantically equivalent for
placement.

Default: `true`
"""
isequivalent(::Type{<:AA}, a::TN, b::TN) = true

"""
    ismappable(::Type{A}, c::Component) :: Bool where {A <: Architecture}

Return `true` if some task can be mapped to `c`.

Default: `true`
"""
ismappable(::Type{<:AA}, c::Component) = true

"""
    canmap(::Type{A}, t::TaskgraphNode, c::Component) :: Bool where {A <: Architecture}

Return `true` if `t` can be mapped to `c`.

Default: `true`
"""
canmap(::Type{<:AA}, t::TN, c::Component) = true 

# Routing Queries

"""
    canuse(::Type{A}, item::Union{Port,Link,Component}, edge::TaskgraphEdge)::Bool where {A <: Architecture}

Return `true` if `edge` can use `item` as a routing resource.

Default: `true`
"""
canuse(::Type{<:AA}, item::PLC, edge::TE) = true

"""
    getcapacity(::Type{A}, item::Union{Port,Link,Component}) where {A <: Architecture}

Return the capacity of routing resource `item`.

Default: `1`
"""
getcapacity(::Type{<:AA}, item) = 1

"""
    is_source_port(::Type{A}, port::Port, edge::TaskgraphEdge)::Bool where {A <: Architecture}

Return `true` if `port` is a valid source port for `edge`.

Default: `true`
"""
is_source_port(::Type{<:AA}, port::Port, edge::TE) = true

"""
    is_sink_port(::Type{A}, port::Port, edge::TaskgraphEdge)::Bool where {A <: Architecture}

Return `true` if `port` is a vlid sink port for `edge`.

Default: `true`
"""
is_sink_port(::Type{<:AA}, port::Port, edge::TE) = true

"""
    needsrouting(::Type{A}, edge::TaskgraphEdge)::Bool where {A <: Architecture}

Return `true` if `edge` needs to be routed.

Default: `true`
"""
needsrouting(::Type{<:AA}, edge::TE) = true




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
        Architecture,
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
        Input,
        Output,
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
        build_distance,
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
