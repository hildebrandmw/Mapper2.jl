module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)

export Address, Component, TopLevel,
        # Architecture Types
        AbstractArchitecture,
        TopLevel,
        Component,
        # Architecture constructor types
        OffsetRule, 
        PortRule,
        # Architecture constructor functions
        add_port,
        add_child,
        connect_ports,
        connection_rule,
        build_mux,
        # Taskgraph Types
        AbstractTaskgraphConstructor,
        TaskgraphNode,
        TaskgraphEdge,
        Taskgraph,
        # Taskgraph Functions - todo: Add the necessary functions here.
        getsources,
        getsinks,
        apply_transforms,
        getnodes,
        getnode,
        getedges,
        getedge,
        hasnode,
        nodenames,
        num_nodes,
        num_edges,
        add_node,
        add_edge,
        out_edges,
        in_edges,
        out_nodes,
        ## Map structures
        Map,
        Mapping,
        NewMap,
        ## Placement
        place,
        get_placement_struct,
        # Simulated Annealing
        SAStruct,
        AbstractSANode,
        AbstractSAEdge,
        AbstractAddressData,
        BasicSANode,
        BasicSAEdge,
        # Routing
        route,
        RoutingStruct,
        AbstractRoutingLink,
        AbstractLinkAnnotator,
        # Pathfinder
        Pathfinder,
        # TODO: Move these functions out of here
        oneofin,
        push_to_dict

###############################
# Common types and operations #
###############################
include("Debug.jl")
include("Addresses.jl")
include("Helper.jl")

include("Taskgraphs.jl")
include("Architecture/Architecture.jl")
include("MapType/MapType.jl")

include("Placement/Place.jl")
include("Routing/Routing.jl")

# Use submodules to make exports visible.
using .Debug
using .Addresses
using .Helper
using .Taskgraphs
using .Architecture
using .MapType
using .Place
using .Routing

# if USEPLOTS
#     include("Plots/Plots.jl")
# end

end #module Mapper2
