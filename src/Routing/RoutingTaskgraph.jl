#=
Data structure recording the start and stop nodes for each link in the taskgraph.
=#
abstract type AbstractRoutingTaskgraph end

struct DefaultRoutingTaskgraph <: AbstractRoutingTaskgraph
    start_stop::Vector{Tuple{Vector{Int64}, Vector{Int64}}}
end

start_nodes(t::DefaultRoutingTaskgraph, i::Integer) = t.start_stop[i][1]
stop_nodes(t::DefaultRoutingTaskgraph, i::Integer) = t.start_stop[i][2]

function build_routing_taskgraph(m::Map{A,D}, rg::RoutingGraph) where {
            A <: AbstractArchitecture, D}
    # Debug printing
    DEBUG && print_with_color(:cyan, "Building Default Routing Taskgraph.\n")
    # Unpack map
    taskgraph       = m.taskgraph
    architecture    = m.architecture
    # Allocate a StartStopNodes vector with an index for each edge in the
    # base taskgraph.
    start_stop = Vector{Tuple{Vector{Int64},Vector{Int64}}}(num_edges(taskgraph))
    # Iterate through all edges in the taskgraph
    for (i,edge) in enumerate(getedges(taskgraph))
        # Get the source nodes names
        sources = getpath.(m, getsources(edge))
        sinks   = getpath.(m, getsinks(edge))
        # Collect the nodes in the routing graph for these ports.
        start = collect_nodes(architecture, rg, edge, sources, :source)
        stop  = collect_nodes(architecture, rg, edge, sinks, :sink)
        start_stop[i] = (start,stop)
    end
    return DefaultRoutingTaskgraph(start_stop)
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

################################################################################
# Default extraction for source and sink ports.
################################################################################

# Functions defined in Routing.jl

# isvalid_source_port
# isvalid_sink_port
