mutable struct EdgePath
    path::Vector{Int64}
end
EdgePath() = EdgePath(Int64[])

#-- iterator interface for EdgePath
# Just redirect to the iterator for the internal vector.
Base.start(e::EdgePath)   = start(e.path)
Base.next(e::EdgePath, s) = next(e.path, s)
Base.done(e::EdgePath, s) = done(e.path, s)
Base.length(e::EdgePath)  = length(e.path)

struct PathTracker
    edges::Vector{EdgePath}
end
PathTracker(n::Integer) = PathTracker([EdgePath() for i = 1:n])


Base.getindex(pt::PathTracker, i::Integer) = pt.edges[i]
Base.setindex!(pt::PathTracker, e::EdgePath, i::Integer) = setindex!(pt.edges,e,i)
Base.length(pt::PathTracker) = length(pt.edges)

struct RoutingStruct{RG <: RoutingGraph,
                     LA <: AbstractLinkAnnotator,
                     RT <: AbstractRoutingTaskgraph}
    "Routing Resources Graph"
    resources_graph ::RG
    "Annotations for the graph"
    link_info     ::LA
    "Paths for links in the taskgraph"
    paths           ::PathTracker
    "Start and stop nodes for each connection to be routed."
    routing_taskgraph::RT
end

function RoutingStruct(m::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # Create the routing resources graph from the architecture.
    resources_graph = routing_graph(architecture)
    # Annotate the links in the routing graph with the custom structure defined
    # by the architecture type.
    link_info = annotate(A, resources_graph)
    # Initialize the paths variable.
    paths = PathTracker(num_edges(taskgraph))
    # Get start and stop nodes for each taskgraph.
    routing_taskgraph = build_routing_taskgraph(m, resources_graph)

    return RoutingStruct(
        resources_graph,
        link_info,
        paths,
        routing_taskgraph,
    )
end
#-- Accessors
getpath(rs::RoutingStruct, i::Integer) = rs.paths[i]
setpath(rs::RoutingStruct, path::EdgePath, i::Integer) = rs.paths[i] = path
get_link_info(rs::RoutingStruct) = rs.link_info
get_link_info(rs::RoutingStruct, i::Integer) = rs.link_info[i]

start_nodes(rs::RoutingStruct, i::Integer) = start_nodes(rs.routing_taskgraph, i)
stop_nodes(rs::RoutingStruct, i::Integer) = stop_nodes(rs.routing_taskgraph, i)

nodecost(rs::RoutingStruct, i::Integer) = nodecost(rs.link_info, i)
#---------#
# Methods #
#---------#
iscongested(rs::RoutingStruct) = iscongested(rs.link_info)
function iscongested(rs::RoutingStruct, path::Integer)
    p = getpath(rs, path)
    for i in p
        iscongested(get_link_info(rs,i)) && return true
    end
    return false
end
"""
    remove_route(rs::RoutingStruct, index::Integer)

Rip up the current routing for the given link.
"""
function clear_route(rs::RoutingStruct, index::Integer)
    #=
    1. Get the path for the link.
    2. Step through each architecture link on that path, remove the link index
        from that link info.
    3. Set the path to an empty set.
    =#
    path = getpath(rs, index)
    for node in path
        remlink(get_link_info(rs, node), index)
    end
    # Clear the path variable
    setpath(rs, EdgePath(), index) 
    return nothing
end

function set_route(rs::RoutingStruct, path::EdgePath, index::Integer)
    # This should always be the case.
    @assert length(getpath(rs, index)) == 0
    for node in path
        addlink(get_link_info(rs, node), index)
    end
    setpath(rs, path, index)
end

canuse(rs::RoutingStruct, arch_link::Integer, task_link::Integer) = true
