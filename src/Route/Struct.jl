"""
    RoutingStruct(RG,L,C}

Central type for routing.

# Parameter Restrictions:
* `RG <: RoutingGraph`
* `L <: AbstractRoutingLink`
* `c <: AbstractRoutingChannel`

# Fields
* `graph::RG` - Graph encoding the architecture connectivity.
* `links::Vector{L}` - Link annotations for each vertex in `graph`.
* `paths::Vector{SparseDiGraph{Int}}` - Routings taken by each channel.
* `channels::Vector{C}` - Routing taskgraph.

# Constructor
    RoutingStruct(m::Map{A,D})

# See also:

$(make_ref_list((:RoutingGraph, :AbstractRoutingLink, :AbstractRoutingChannel)))
"""
struct RoutingStruct{RG <: RoutingGraph, L <: ARL, C <: ARC}
    graph   ::RG
    links   ::Vector{L}
    paths   ::Vector{SparseDiGraph{Int}}
    channels::Vector{C}
end

function RoutingStruct(m::Map{A,D}) where {A,D}
    # Unpack some fields from the map
    architecture = m.architecture
    taskgraph    = m.taskgraph
    @info "Building Resource Graph"

    graph = routing_graph(architecture)
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

        mapping[i] = routing_path
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

################################################################################
# Routing Link Annotation
################################################################################
function annotate(arch::TopLevel{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    @info "Annotating Graph Links"
    maprev = rev_dict(rg.map)

    # Initialize this to any. We'll clean it up later.
    @compat routing_links_any = Vector{Any}(uninitialized, nv(rg.graph))

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
function build_routing_taskgraph(m::Map{A}, r::RoutingGraph) where {A <: AbstractArchitecture}
    # Debug printing
    @debug "Building Default Routing Taskgraph"
    # Unpack map
    taskgraph = m.taskgraph
    arch      = m.architecture
    # Decode the routing task type for this architecture
    channels = map(getedges(taskgraph)) do edge
        # Get source and destination nodes paths
        sources = MapperCore.getpath.(m, getsources(edge))
        sinks   = MapperCore.getpath.(m, getsinks(edge))
        # Convert these to indices in the routing graph
        start = collect_nodes(arch, r.map, edge, sources, :source)
        stop  = collect_nodes(arch, r.map, edge, sinks, :sink)
        # Build the routing channel type
        return routing_channel(A, start, stop, edge)
    end
    # Return the collection of channels
    return channels
end

function collect_nodes(arch::TopLevel{A,D},
                       pathmap,
                       edge::TaskgraphEdge,
                       paths,
                       dir) where {A,D}

    nodes = Vector{Int64}[]
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
        port_paths = [PortPath(port, path) for port in ports]
        port_indices = [pathmap[pp] for pp in port_paths]

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
function get_routing_ports(::Type{A}, e::TaskgraphEdge, c::Component, dir) where A <: AbstractArchitecture
    if dir == :source
        return [k for (k,v) in c.ports if checkclass(v,dir) && is_source_port(A,v,e)]
    elseif dir == :sink
        return [k for (k,v) in c.ports if checkclass(v,dir) && is_sink_port(A,v,e)]
    else
        throw(KeyError("Symbol: $dir not recognized"))
    end
end
