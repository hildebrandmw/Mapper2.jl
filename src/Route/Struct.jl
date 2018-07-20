"""
Central type for routing. Not meant for extending.

API
---
* [`allroutes`](@ref)
* [`getroute`](@ref)
* [`alllinks`](@ref)
* [`getlink`])(@ref)
* [`start_vertices`](@ref)
* [`stop_vertices`](@ref)
* [`getchannel`](@ref)
* [`getmap`](@ref)
* [`getgraph`](@ref)
* [`iscongested`](@ref)
* [`clear_route`](@ref)
* [`setroute`](@ref)

"""
struct RoutingStruct{L <: RoutingLink, C <: RoutingChannel}
    "Base [`RoutingGraph`](@ref) for the underlying routing architecture."
    architecture_graph      ::RoutingGraph

    """
    Annotating [`RoutingLink`](@ref) for each routing element in 
    `architecture_graph`.
    """
    graph_vertex_annotations::Vector{L}

    """
    Graphs of routing resources used by each channel.
    """
    routings                ::Vector{SparseDiGraph{Int}}

    """
    `Vector{RoutingChannel}` containing the channel information for the 
    taskgraph.
    """
    channels                ::Vector{C}

    """
    Convenience structure mapping local channel indices back to edge indices
    in the parent taskgraph.
    """
    channel_index_to_taskgraph_index::Dict{Int,Int}
end

function RoutingStruct(map::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = map.architecture
    taskgraph    = map.taskgraph
    @debug "Building Resource Graph"

    architecture_graph = routing_graph(architecture)
    # Annotate the links in the routing graph with the custom structure defined
    # by the architecture type.
    graph_vertex_annotations = annotate(architecture, architecture_graph)
    # Get start and stop nodes for each taskgraph.
    channels, channel_dict = build_routing_taskgraph(map, architecture_graph)
    # Initialize the paths variable.
    routings = [SparseDiGraph{Int}() for i in 1:length(channels)]

    return RoutingStruct(
        architecture_graph,
        graph_vertex_annotations,
        routings,
        channels,
        channel_dict,
    )
end

#---------#
# Methods #
#---------#
"""
$(SIGNATURES)

Return all routings in `routing_struct`.
"""
allroutes(routing_struct::RoutingStruct) = routing_struct.routings

"""
$(SIGNATURES)

Return route for channel `index`.
"""
getroute(routing_struct::RoutingStruct, index) = routing_struct.routings[index]

"""
$(SIGNATURES)

Return `Vector{RoutingLink}` for all links in `routing_struct.
"""
alllinks(routing_struct::RoutingStruct) = routing_struct.graph_vertex_annotations

"""
$(SIGNATURES)

Return `<:RoutingLink` for link in `routing_struct` with indes `i`.
"""
getlink(routing_struct::RoutingStruct, i::Integer) = routing_struct.graph_vertex_annotations[i]


"""
$(SIGNATURES)

Return `Vector{PortVertices}` of start vertices for channel index `i`.
"""
start_vertices(routing_struct::RoutingStruct, i::ChannelIndex) = 
    start_vertices(routing_struct.channels[i])

"""
$(SIGNATURES)

Return `Vector{PortVertices}` of stop vertices for channel index `i`.
"""
stop_vertices(routing_struct::RoutingStruct, i::ChannelIndex) = 
    stop_vertices(routing_struct.channels[i])

"""
$(SIGNATURES)

Return `<:RoutingChannel` with indesx `i`.
"""
getchannel(routing_struct::RoutingStruct, i::ChannelIndex) = routing_struct.channels[i]

getmap(routing_struct::RoutingStruct) = getmap(routing_struct.architecture_graph)
getgraph(routing_struct::RoutingStruct) = routing_struct.architecture_graph

iscongested(routing_struct::RoutingStruct) = 
    iscongested(routing_struct.graph_vertex_annotations)
iscongested(routing_struct::RoutingStruct, path) = 
    iscongested(routing_struct, getroute(routing_struct, path))

function iscongested(routing_struct::RoutingStruct, path::SparseDiGraph{Int})
    for i in vertices(path)
        iscongested(getlink(routing_struct, i)) && return true
    end
    return false
end

"""
    clear_route(rs::RoutingStruct, channel::ChannelIndex)

Rip up the current routing for the given link.
"""
function clear_route(rs::RoutingStruct, channel::ChannelIndex)
    #=
    1. Get the path for the link.
    2. Step through each architecture link on that path, remove the link index
        from that link info.
    3. Set the path to an empty set.
    =#
    path = getroute(rs, channel)
    for i in vertices(path)
        remchannel(getlink(rs, i), channel)
    end
    # Clear the path variable
    rs.routings[channel] = SparseDiGraph{Int}()
    return nothing
end

function setroute(rs::RoutingStruct, route::SparseDiGraph, channel::ChannelIndex)
    # This should always be the case - this assertion is to catch bugs.
    @assert nv(getroute(rs, channel)) == 0
    for i in vertices(route)
        addchannel(getlink(rs, i), channel)
    end
    rs.routings[channel] = route
end

function record(m::Map, r::RoutingStruct)
    # Get the dictionary mapping channel indices back to taskgraph edge indices.
    channel_dict = r.channel_index_to_taskgraph_index
    routes = translate_routes(getgraph(r), allroutes(r))
    for (i,route) in enumerate(routes)
        m.mapping[channel_dict[i]] = route
    end
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

################################################################################
# Routing Link Annotation
################################################################################
function annotate(arch::TopLevel{A}, rg::RoutingGraph) where A <: Architecture
    @debug "Annotating Graph Links"
    maprev = rev_dict(rg.map)

    # Initialize this to any. We'll clean it up later.
    routing_links_any = Vector{Any}(undef, nv(rg.graph))

    for (i, path) in maprev
        routing_links_any[i] = annotate(A, arch[path])
    end
    # Clean up types
    routing_links = typeunion(routing_links_any)

    @debug "Type of Routing Link Annotations: $(typeof(routing_links))"
    return routing_links
end

################################################################################
# Routing Taskgraph Constructor
################################################################################
function build_routing_taskgraph(m::Map{A}, r::RoutingGraph) where {A <: Architecture}
    # Debug printing
    @debug "Building Default Routing Taskgraph"
    # Unpack map
    taskgraph = m.taskgraph
    arch      = m.architecture

    # Get the list of channels that need routing.
    edges = getedges(taskgraph)
    edge_indices_to_route = [i for (i,e) in enumerate(edges) if needsrouting(A, e)]

    # Create routing channels for all edges that need routing.
    channels = map(edge_indices_to_route) do index
        # Unpack the edge
        edge = edges[index]
        # Get source and destination nodes paths
        sources = MapperCore.getpath.(m, getsources(edge))
        sinks   = MapperCore.getpath.(m, getsinks(edge))
        # Convert these to indices in the routing graph
        start = collect_nodes(arch, r.map, edge, sources, :source)
        stop  = collect_nodes(arch, r.map, edge, sinks, :sink)
        # Build the routing channel type
        return routing_channel(A, start, stop, edge)
    end

    # Create a dictionary mapping indices in the "channels" vector to indices
    # in the original vector of edges.
    channel_dict = Dict(i => edge_indices_to_route[i] for i in 1:length(channels))

    # Return the collection of channels
    return channels, channel_dict
end

function collect_nodes(
        arch::TopLevel{A,D},
        pathmap,
        edge::TaskgraphEdge,
        paths,
        dir
    ) where {A,D}

    nodes = Vector{PortVertices}()
    # Iterate through the source paths - get the port names.
    for path in paths
        # Get the component from the architecture
        component = arch[path]
        ports = get_routing_ports(A, edge, component, dir)

        # The ports are just a collection of strings.
        #
        # 1. Create port path types from these ports using the path for the
        #    component that they belong to.
        #
        # 2. Use these full paths to index into the portmap dictionary to
        #    get the numbers in the routing graph.
        port_paths = [catpath(path, Path{Port}(port)) for port in ports]
        port_indices = PortVertices([pathmap[pp] for pp in port_paths])

        # Add this to the collection of nodes
        push!(nodes, port_indices)
    end
    return nodes
end

"""
    get_routing_ports(::Type{A}, e::TaskgraphEdge, c::Component, dir::Symbol)

Return an array of the names of the ports of `c` that can serve as the correct
function for `e`, depending on the value fo `dir`. Valid inputs for `dir` are:

- `:source` - indicates a source port for directed communication.
- `:sink` - indicates a sink port for direction communication.
"""
function get_routing_ports(::Type{A}, e::TaskgraphEdge, c::Component, dir) where A <: Architecture
    if dir == :source
        return [k for (k,v) in c.ports if checkclass(invert(v),dir) && is_source_port(A,v,e)]
    elseif dir == :sink
        return [k for (k,v) in c.ports if checkclass(invert(v),dir) && is_sink_port(A,v,e)]
    else
        throw(KeyError("Symbol: $dir not recognized"))
    end
end
