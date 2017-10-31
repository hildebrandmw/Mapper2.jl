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
        start = collect_nodes(architecture, rg, edge, sources, get_source_ports)
        stop  = collect_nodes(architecture, rg, edge, sinks, get_sink_ports)
        start_stop[i] = (start,stop)
    end
    return DefaultRoutingTaskgraph(start_stop)
end

function collect_nodes(arch, resource_graph, edge, paths, f::Function)
    A = architecture(arch)
    # Iterate through the source paths - get the port names.
    first = true
    local port_paths
    for path in paths
        newpaths = f(A, edge, arch[path])
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

################################################################################
# Default extraction for source and sink ports.
################################################################################
function get_source_ports(::Type{A}, edge, component) where A <: AbstractArchitecture
    # Just grab all the output ports of the component.
    paths = [k for (k,v) in component.ports if v.class in PORT_SINKS]
    return paths
end

function get_sink_ports(::Type{A}, edge, component) where A <: AbstractArchitecture
    # Just grab all the output ports of the component.
    paths = [k for (k,v) in component.ports if v.class in PORT_SOURCES]
    return paths
end
