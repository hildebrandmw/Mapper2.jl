passfail(b::Bool) = b ? "passed" : "failed"

################################################################################
# Routing Checks
################################################################################
function check_routing(m::Map)
    port_okay = check_ports(m)
    capacity_okay = check_capacity(m)
    graph_okay = check_routing_connectivity(m)
    arch_okay = check_architecture_connectivity(m)
    resource_okay = check_architecture_resources(m)

    @info """
        Routing Summary
        ---------------
        Congestion Check:   $(passfail(capacity_okay))

        Port Check:         $(passfail(port_okay))

        Graph Connectivity: $(passfail(graph_okay))

        Architecture Check: $(passfail(arch_okay))

        Resource Check:     $(passfail(resource_okay))
        """

    return foldl(&, (capacity_okay, port_okay, graph_okay, arch_okay, resource_okay))
end

function check_ports(m::Map{A}) where A
    edges = m.mapping.edges
    arch  = m.architecture
    tg    = m.taskgraph

    success = true
    for (i,edge) in enumerate(edges)
        # Get the taskgraph sources and sinks
        tg_edge = getedge(tg, i) 

        tg_sources = getsources(tg_edge)
        tg_sinks   = getsinks(tg_edge)

        routing_sources = Set(source_vertices(edge.path))
        routing_sinks   = Set(sink_vertices(edge.path))

        # Check that source ports are valid for the location of the placed tasks.
        for source in tg_sources
            # Get the mapped component path
            sourcepath = getpath(m, source)
            found = false
            for rs in routing_sources
                if prefix(rs) == sourcepath && isvalid_source_port(A, arch[rs], tg_edge)
                    found = true
                    delete!(routing_sources, rs)
                    break
                end
            end
            if found == false
                success = false
                @error """
                    Source Port for edge $i at $sourcepath not found.
                    """
            end
        end
        if length(routing_sources) > 0
            success = false
            @error """
                Routing has more sources than expected. Sources remaining:
                $routing_sources
                """
        end

        for sink in tg_sinks
            # Get the mapped component path
            sinkpath = getpath(m, sink)
            found = false
            for rs in routing_sinks
                if prefix(rs) == sinkpath && isvalid_sink_port(A, arch[rs], tg_edge)
                    found = true
                    delete!(routing_sinks, rs)
                    break
                end
            end
            if found == false
                success = false
                @error """
                    Sink Port for edge $i at $sinkpath not found.
                    """
            end
        end

        if length(routing_sinks) > 0
            success = false
            @error """
                Routing has more sinks than expected. Sources remaining:
                $routing_sinks
                """
        end
    end
    return success
end

function check_capacity(m::Map{A}) where A <: AbstractArchitecture
    arch    = m.architecture
    edges   = m.mapping.edges

    times_resource_used = Dict{Any,Int}()
    resource_to_edge    = Dict{Any,Vector{Int}}()

    # categorize edges
    for (i,edge) in enumerate(edges)
        for v in vertices(edge.path)
            add_to_dict(times_resource_used, v)
            push_to_dict(resource_to_edge, v, i)
        end
    end

    congested_edges = Set{Int}() 
    for (path, occupancy) in times_resource_used
        # record congested edges
        if occupancy > getcapacity(A, arch[path])
            push!(congested_edges, resource_to_edge[path]...)
        end
    end

    if length(congested_edges) > 0
        @error """
            Mapping has routing congestion.

            Congested edges: $(sort(collect(congested_edges)))
            """
        return false
    end
    return true
end


"""
    check_architecture_connectivity(m::Map)

Traverse each routing. Get the underlying architecture components and make sure
that the routing does not violate any connectings in the architecture.
"""
function check_architecture_connectivity(m::Map)
    # Get the edge mapping
    arch  = m.architecture
    edges = m.mapping.edges

    success = true
    for edge in edges
        g = edge.path
        for i in vertices(g), j in outneighbors(g, i)
            if !isconnected(arch, i, j)
                success = false
            end
        end
    end
    return success
end

function check_routing_connectivity(m::Map)
    edges = m.mapping.edges

    success = true
    # Construct a lightgraph from the sparsegraph
    for (i,edge) in enumerate(edges)
        path = edge.path
        g, d = make_lightgraph(path)

        # Check for weakconnectivity
        if !is_weakly_connected(g)
            @error """
                Graph for edge number $i is not connected.
                """
            success = false
        end
        # Check paths from source to destination.
        sources = source_vertices(path)
        sinks   = sink_vertices(path)
        for src in sources, snk in sinks
            if !has_path(g, d[src], d[snk])
                @error """
                    No routing path for edge number $i from $src to $snk.
                    """
                success = false
            end
        end
    end
    return success
end

function check_architecture_resources(m::Map{A}) where A
    edges = m.mapping.edges
    arch  = m.architecture

    success = true
    for (i, edge) in enumerate(edges)
        tg_edge = getedge(m.taskgraph, i) 
        path = edge.path
        for v in vertices(path)
            # Checking routing
            if !canuse(A, arch[v], tg_edge)
                success = false
                @error """
                    Taskgraph edge number $i can not use resource $v. 
                    """
            end
        end
    end
    return success
end
