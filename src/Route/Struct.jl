################################################################################
# Routing Struct
################################################################################
struct RoutingStruct{RG <: RoutingGraph,
                     L <: AbstractRoutingLink,
                     C <: AbstractRoutingChannel}

    "Routing Resources Graph"
    graph   ::RG
    "Annotaions for the graph"
    links   ::Vector{L}
    "Paths for links in the taskgraph"
    paths   ::Vector{SparseDiGraph{Int}}
    "Start and stop nodes for each connection to be routed."
    channels::Vector{C}
end

function RoutingStruct(m::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # Create the routing resources graph from the architecture.
    @info "Building Resource Graph"

    graph = routing_graph(architecture)
    # Make sure map structure in graph is one to one
    let
        maprev = rev_dict_safe(graph.map)
        for (k,v) in maprev
            length(v) > 1  && throw(ErrorException("$k => $v"))
        end
    end

    @debug routing_graph_info(graph)
    # Annotate the links in the routing graph with the custom structure defined
    # by the architecture type.
    links = annotate(architecture, graph)
    # Initialize the paths variable.
    paths = [SparseDiGraph{Int}() for i in 1:num_edges(taskgraph)]
    # Get start and stop nodes for each taskgraph.
    channels = build_routing_taskgraph(m, graph)

    return RoutingStruct(
        graph,
        links,
        paths,
        channels,
    )
end
#-- Accessors
allpaths(rs::RoutingStruct) = rs.paths
getpath(rs::RoutingStruct, i::Integer) = rs.paths[i]
setpath(rs::RoutingStruct, path::SparseDiGraph, i::Integer) = rs.paths[i] = path

alllinks(rs::RoutingStruct) = rs.links
getlink(rs::RoutingStruct, i::Integer) = rs.links[i]

Base.start(rs::RoutingStruct, i::Integer) = start(rs.channels[i])
stop(rs::RoutingStruct, i::Integer) = stop(rs.channels[i])

getchannel(rs::RoutingStruct, i::Integer) = rs.channels[i]

getmap(r::RoutingStruct) = getmap(r.graph)

#---------#
# Methods #
#---------#
iscongested(rs::RoutingStruct) = iscongested(rs.links)
iscongested(rs::RoutingStruct, path::Integer) = iscongested(rs, getpath(rs, path))

function iscongested(rs::RoutingStruct, path::SparseDiGraph{Int})
    for i in vertices(path)
        iscongested(getlink(rs, i)) && return true
    end
    return false
end

"""
    clear_route(rs::RoutingStruct, index::Integer)

Rip up the current routing for the given link.
"""
function clear_route(rs::RoutingStruct, channel::Integer)
    #=
    1. Get the path for the link.
    2. Step through each architecture link on that path, remove the link index
        from that link info.
    3. Set the path to an empty set.
    =#
    path = getpath(rs, channel)
    for i in vertices(path)
        remchannel(getlink(rs, i), channel)
    end
    # Clear the path variable
    setpath(rs, SparseDiGraph{Int}(), channel)
    return nothing
end

function set_route(rs::RoutingStruct, path::SparseDiGraph, channel::Integer)
    # This should always be the case - this assertion is to catch bugs.
    @assert nv(getpath(rs, channel)) == 0
    for i in vertices(path)
        addchannel(getlink(rs, i), channel)
    end
    setpath(rs, path, channel)
end

################################################################################
# Method for recording the post-place structure into the Map.
################################################################################
function reverse_lookup(index, portmap_rev, linkmap_rev)
    return haskey(portmap_rev, index) ? portmap_rev[index] : linkmap_rev[index]
end

function record(m::Map, r::RoutingStruct)
    architecture    = m.architecture
    mapping         = m.mapping

    maprev = rev_dict(getmap(r))
    for (i,path) in enumerate(allpaths(r))

        routing_path = get_routing_path(architecture, path, maprev)
        # Extract the sources and destinations for this edges of the taskgraph.
        taskgraph_edge  = getedge(m.taskgraph, i)
        sources         = getsources(taskgraph_edge)
        sinks           = getsinks(taskgraph_edge)

        metadata = Dict("sources" => sources, "sinks" => sinks,)
        mapping[i] = EdgeMap(routing_path, metadata = metadata)
    end
    return nothing
end

function get_routing_path(arch::TopLevel{A,D}, g, maprev) where {A,D}
    routing_path = SparseDiGraph{Any}()
    # Add vertices
    for v in vertices(g)
        path = maprev[v]
        add_vertex!(routing_path, path)
    end
    # Add edges
    for src in vertices(g), dst in outneighbors(g, src)
        add_edge!(routing_path, maprev[src], maprev[dst])
    end
    return routing_path
end
