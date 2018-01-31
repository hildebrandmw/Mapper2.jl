struct ChannelPath
    links::Vector{Int64}
end
ChannelPath() = ChannelPath(Int64[])

# Simple redirection methods
for fn in (:start, :length, :first, :last)
    @eval (Base.$fn)(e::ChannelPath) = ($fn)(e.links)
end
for fn in (:next, :done, :getindex)
    @eval (Base.$fn)(e::ChannelPath, s) = ($fn)(e.links, s)
end

struct RoutingStruct{RG <: RoutingGraph, 
                     L <: AbstractRoutingLink, 
                     C <: AbstractRoutingChannel}
    "Routing Resources Graph"
    graph   ::RG
    "Annotaions for the graph"
    links   ::Vector{L}
    "Paths for links in the taskgraph"
    paths   ::Vector{ChannelPath}
    "Start and stop nodes for each connection to be routed."
    channels::Vector{C}
end

function RoutingStruct(m::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # Create the routing resources graph from the architecture.
    graph = routing_graph(architecture)
    # Annotate the links in the routing graph with the custom structure defined
    # by the architecture type.
    links = annotate(architecture, graph)
    # Initialize the paths variable.
    paths = [ChannelPath() for i in 1:num_edges(taskgraph)]
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
MapType.getpath(rs::RoutingStruct, i::Integer) = rs.paths[i]
setpath(rs::RoutingStruct, path::ChannelPath, i::Integer) = rs.paths[i] = path

alllinks(rs::RoutingStruct) = rs.links
getlink(rs::RoutingStruct, i::Integer) = rs.links[i]

Base.start(rs::RoutingStruct, i::Integer) = start(rs.channels[i])
stop(rs::RoutingStruct, i::Integer) = stop(rs.channels[i])

getchannel(rs::RoutingStruct, i::Integer) = rs.channels[i]

portmap(rs::RoutingStruct) = portmap(rs.graph)
linkmap(rs::RoutingStruct) = linkmap(rs.graph)

#---------#
# Methods #
#---------#
iscongested(rs::RoutingStruct) = iscongested(rs.links)
iscongested(rs::RoutingStruct, path::Integer) = iscongested(rs, getpath(rs, path))

function iscongested(rs::RoutingStruct, path::ChannelPath)
    for i in path
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
    for link in path
        remchannel(getlink(rs, link), channel)
    end
    # Clear the path variable
    setpath(rs, ChannelPath(), channel)
    return nothing
end

function set_route(rs::RoutingStruct, path::ChannelPath, channel::Integer)
    # This should always be the case - this assertion is to catch bugs.
    @assert length(getpath(rs, channel)) == 0
    for link in path
        addchannel(getlink(rs, link), channel)
    end
    setpath(rs, path, channel)
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
    errors = verify_routing(m, rs)
    if errors.num_errors > 0
        m.metadata["routing_success"] = false
    else
        m.metadata["routing_success"] = true
    end
    mapping = m.mapping
    # Run safe reverse on the port map since multiple port paths can point to
    # the same port.
    portmap_rev = rev_dict_safe(portmap(rs))
    # Run normal reverse on the link map since all links should only have
    # a single instance.
    linkmap_rev = rev_dict(linkmap(rs))
    # For now - just dump everything.
    for (i,path) in enumerate(allpaths(rs))
        routing_path = get_routing_path(architecture, path, portmap_rev, linkmap_rev)
        # Extract the sources and destinations for this edges of the taskgraph.
        taskgraph_edge = getedge(m.taskgraph, i)
        sources = getsources(taskgraph_edge)
        sinks   = getsinks(taskgraph_edge)
        metadata = Dict(
                    "sources" => sources,
                    "sinks" => sinks,
                   )
        mapping[i] = EdgeMap(routing_path, metadata = metadata)
    end
    return errors
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
            # exit through another port without taking a link in between.
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
