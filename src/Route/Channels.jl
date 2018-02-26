const ARC = AbstractRoutingChannel
struct RoutingChannel <: ARC
    start::Vector{Int64}
    stop ::Vector{Int64}
end
RoutingChannel(start, stop, taskgraph_edge) = RoutingChannel(start, stop)

Base.start(r::ARC)   = r.start
stop(r::ARC)         = r.stop

#=
Fallback for choosing links to give priority to during routing.
=#
Base.isless(::ARC, ::ARC) = false

function build_routing_taskgraph(m::Map{A}, rg::RoutingGraph) where {A <: AbstractArchitecture}
    # Debug printing
    @info "Building Default Routing Taskgraph"
    # Unpack map
    taskgraph       = m.taskgraph
    architecture    = m.architecture
    # Decode the routing task type for this architecture
    task_type = routing_channel_type(A)
    # Allocate a StartStopNodes vector with an index for each edge in the
    # base taskgraph.
    channels = Vector{task_type}(num_edges(taskgraph))
    # Iterate through all edges in the taskgraph
    for (i,edge) in enumerate(getedges(taskgraph))
        # Get the source nodes names
        sources = MapperCore.getpath.(m, getsources(edge))
        sinks   = MapperCore.getpath.(m, getsinks(edge))
        # Collect the nodes in the routing graph for these ports.
        start = collect_nodes(architecture, rg, edge, sources, :source)
        stop  = collect_nodes(architecture, rg, edge, sinks, :sink)
        channels[i] = task_type(start,stop,edge)
    end
    return channels
end

function collect_nodes(arch::TopLevel{A,D},
                       resource_graph,
                       edge,
                       paths,
                       symbol) where {A,D}

    # Iterate through the source paths - get the port names.
    first = true
    local port_paths
    for path in paths
        newpaths = get_routing_ports(A, edge, arch[path], symbol)
        # Augment the port paths to get a full path.
        if first
            port_paths = [PortPath(p, path) for p in newpaths]
            first = false
        else
            full_paths = [PortPath(p, path) for p in newpaths]
            append!(port_paths, full_paths)
        end
    end
    # Augment all of the paths to get the full port path
    # Convert these paths to indices
    return unique(resource_graph.portmap[p] for p in port_paths)
end

function get_routing_ports(::Type{A}, edge::TaskgraphEdge, component::Component, sym) where A <: AbstractArchitecture
    if sym == :source
        return [k for (k,v) in component.ports if isvalid_source_port(A,v,edge)]
    elseif sym == :sink
        return [k for (k,v) in component.ports if isvalid_sink_port(A,v,edge)]
    else
        KeyError("Symbol: $sym not recognized")
    end
end
