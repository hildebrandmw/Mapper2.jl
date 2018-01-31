module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

export Address, Component, TopLevel,
        # Architecture Types
        AbstractArchitecture,
        TopLevel,
        Component,
        Port,
        Link,
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
        RoutingLink,
        AbstractRoutingTask,
        RoutingTask,
        LinkAnnotator,
        LinkState,
        # Interface
        routing_link_type,
        routing_task_type,
        annotate_port,
        annotate_link,
        annotate_component,
        canuse,
        isvalid_source_port,
        isvalid_sink_port,
        # Pathfinder
        Pathfinder

export oneofin, push_to_dict

###############################
# Common types and operations #
###############################
include("Debug.jl")
include("Addresses.jl")
include("Helper.jl")

include("Taskgraphs.jl")
include("Architecture/Architecture.jl")
include("MapType/MapType.jl")

include("Place/Place.jl")
include("Route/Route.jl")

# Use submodules to make exports visible.
using .Debug
@reexport using .Addresses
@reexport using .Helper
@reexport using .Taskgraphs
@reexport using .Architecture
@reexport using .MapType
@reexport using .Place
@reexport using .Routing

# if USEPLOTS
#     include("Plots/Plots.jl")
# end

end #module Mapper2
