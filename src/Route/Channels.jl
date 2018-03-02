const ARC = AbstractRoutingChannel
#=
I'm making the start and stop nodes vector{vector{int}}.
- The outer vector is for each independent component. Thus, if there are 3
    source components, the length of the outer vector will be 3.

- The inner vector points to ports on that component, in the case that one of
    several input/output ports may be used.
=#
struct RoutingChannel <: ARC
    start::Vector{Vector{Int64}}
    stop ::Vector{Vector{Int64}}
end

# Default routing channel doesn't need to look at the taskgraph_edge.
# This is a default rerouting function to provide the 3-argument function
# call for future specialization.
function routing_channel(::Type{A}, start, stop, edge) where {A<:AbstractArchitecture}
    RoutingChannel(start, stop)
end

Base.start(r::ARC)   = r.start
stop(r::ARC)         = r.stop

# Fallback for choosing links to give priority to during routing.
Base.isless(::ARC, ::ARC) = false

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
