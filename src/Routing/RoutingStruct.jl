mutable struct EdgePath{T}
    path::Vector{T}
end
EdgePath() = EdgePath(Int64[])

#-- iterator interface for EdgePath
# Just redirect to the iterator for the internal vector.
Base.start(e::EdgePath)   = start(e.path)
Base.next(e::EdgePath, s) = next(e.path, s)
Base.done(e::EdgePath, s) = done(e.path, s)
Base.length(e::EdgePath)  = length(e.path)
Base.first(e::EdgePath)   = first(e.path)
Base.last(e::EdgePath)    = last(e.path)
Base.getindex(e::EdgePath, i) = getindex(e.path, i)

struct PathTracker
    edges::Vector{EdgePath{Int64}}
end
PathTracker(n::Integer) = PathTracker([EdgePath() for i = 1:n])

Base.getindex(pt::PathTracker, i::Integer) = pt.edges[i]
Base.setindex!(pt::PathTracker, e::EdgePath, i::Integer) = setindex!(pt.edges,e,i)
Base.length(pt::PathTracker) = length(pt.edges)
#- Iterator Interface
Base.start(e::PathTracker)      = start(e.edges)
Base.next(e::PathTracker, s)    = next(e.edges, s)
Base.done(e::PathTracker, s)    = done(e.edges, s)

struct RoutingStruct{RG <: RoutingGraph,
                     LA <: AbstractLinkAnnotator,
                     RT <: AbstractRoutingTaskgraph}
    "Routing Resources Graph"
    resource_graph      ::RG
    "Annotations for the graph"
    link_info           ::LA
    "Paths for links in the taskgraph"
    paths               ::PathTracker
    "Start and stop nodes for each connection to be routed."
    routing_taskgraph   ::RT
end

function RoutingStruct(m::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # Create the routing resources graph from the architecture.
    resource_graph = routing_graph(architecture)
    # Annotate the links in the routing graph with the custom structure defined
    # by the architecture type.
    link_info = annotate(A, resource_graph)
    # Initialize the paths variable.
    paths = PathTracker(num_edges(taskgraph))
    # Get start and stop nodes for each taskgraph.
    routing_taskgraph = build_routing_taskgraph(m, resource_graph)

    return RoutingStruct(
        resource_graph,
        link_info,
        paths,
        routing_taskgraph,
    )
end
#-- Accessors
getpaths(rs::RoutingStruct) = rs.paths
getpath(rs::RoutingStruct, i::Integer) = rs.paths[i]
setpath(rs::RoutingStruct, path::EdgePath, i::Integer) = rs.paths[i] = path

get_link_info(rs::RoutingStruct) = rs.link_info
get_link_info(rs::RoutingStruct, i::Integer) = rs.link_info[i]

start_nodes(rs::RoutingStruct, i::Integer) = start_nodes(rs.routing_taskgraph, i)
stop_nodes(rs::RoutingStruct, i::Integer) = stop_nodes(rs.routing_taskgraph, i)

nodecost(rs::RoutingStruct, i::Integer) = nodecost(rs.link_info, i)

get_portmap(rs::RoutingStruct) = get_portmap(rs.resource_graph)
get_linkmap(rs::RoutingStruct) = get_linkmap(rs.resource_graph)

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
    # This should always be the case - this assertion is to catch bugs.
    @assert length(getpath(rs, index)) == 0
    for node in path
        addlink(get_link_info(rs, node), index)
    end
    setpath(rs, path, index)
end


################################################################################
# Method for recording the post-place structure into the Map.
################################################################################
function reverse_lookup(index, portmap_rev, linkmap_rev)
    return haskey(portmap_rev, index) ? portmap_rev[index] : linkmap_rev[index]
end

function record(m::Map, rs::RoutingStruct)
    architecture = m.architecture
    # Run the verification routine.
    verify_routing(m, rs)
    mapping = getmapping(m)
    # Run safe reverse on the port map since multiple port paths can point to
    # the same port.
    portmap_rev = rev_dict_safe(get_portmap(rs))
    # Run normal reverse on the link map since all links should only have
    # a single instance.
    linkmap_rev = rev_dict(get_linkmap(rs))
    # For now - just dump everything.
    for (i,path) in enumerate(getpaths(rs))
        routing_path = get_routing_path(architecture, path, portmap_rev, linkmap_rev)
        # Get the mapping unit.
        mapping[i] = EdgeMap(routing_path)
    end
    return nothing
end
function get_routing_path(architecture, path, portmap_rev, linkmap_rev)
    routing_path = Any[]
    for (j,node) in enumerate(path)
        a = reverse_lookup(node, portmap_rev, linkmap_rev)

        # Get connectivity information
        if eltype(a) <: PortPath
            # Make an ordered set to keep track of things - this takes care
            # of the instance where a routing path through the architecture
            # can enter one port of something like a multiplexor and 
            # exit through another port without taking a link inbetween.
            set = OrderedSet()
            # Look behind - get the port of this collection that is connected
            # to the previous link.
            if j > 1
                b = reverse_lookup(path[j-1], portmap_rev, linkmap_rev)
                push!(set, get_connected_port(architecture, a, b, :sink))
            end
            # Look ahead - get the port of this collection that is connected
            # to the next link.
            if j < length(path)
                b = reverse_lookup(path[j+1], portmap_rev, linkmap_rev)
                push!(set, get_connected_port(architecture, a, b, :source))
            end
            # Add 1 or 2 port paths to the routing path.
            push!(routing_path, set...)
        else
            # Add 1 link path to the routing set.
            push!(routing_path, a)
        end
    end
    return routing_path
end
