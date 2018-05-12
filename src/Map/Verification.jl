passfail(b::Bool) = b ? "passed" : "failed"

################################################################################
# Routing Checks
################################################################################
function check_routing(m::Map, quiet = false)
    port_okay       = check_ports(m)
    capacity_okay   = check_capacity(m)
    graph_okay      = check_routing_connectivity(m)
    arch_okay       = check_architecture_connectivity(m)
    resource_okay   = check_architecture_resources(m)

    if !quiet
        @info """
            Routing Summary
            ---------------
            Congestion Check:   $(passfail(capacity_okay))

            Port Check:         $(passfail(port_okay))

            Graph Connectivity: $(passfail(graph_okay))

            Architecture Check: $(passfail(arch_okay))

            Resource Check:     $(passfail(resource_okay))
            """
    end

    return foldl(&, (capacity_okay, port_okay, graph_okay, arch_okay, resource_okay))
end

"""
    check_ports(m::Map{A}) where A

Check the source and destination ports for each task in `m`. Perform the 
following checks:

* Each source and destination port for each task channel is valid.
* All sources and destinations for each task channel has been assigned to
    a port.
"""
function check_ports(m::Map{A}) where A
    edges = m.mapping.edges
    arch  = m.architecture
    tg    = m.taskgraph

    taskgraph_edges = getedges(tg)

    success = true
    for (i,routing_graph) in enumerate(edges)
        # Skip this edge if it wasn't supposed to be routed.
        needsrouting(A, taskgraph_edges[i]) || continue

        # Get the taskgraph sources and sinks
        channel = getedge(tg, i) 

        taskgraph_sources = getsources(channel)
        taskgraph_sinks   = getsinks(channel)

        routing_sources = Set(source_vertices(routing_graph))
        routing_sinks   = Set(sink_vertices(routing_graph))

        # Check that source ports are valid for the location of the placed tasks.
        for source in taskgraph_sources
            # Get the mapped component path
            sourcepath = getpath(m, source)
            found = false
            for rs in routing_sources
                if striplast(rs) == sourcepath && is_source_port(A, arch[rs], channel)
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

        for sink in taskgraph_sinks
            # Get the mapped component path
            sinkpath = getpath(m, sink)
            found = false
            for rs in routing_sinks
                if striplast(rs) == sinkpath && is_sink_port(A, arch[rs], channel)
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

"""
    check_capacity(m::Map) 

Performs the following checks:

* The number of channels assigned to each routing resource in `m.architecture`
    does not exceed the stated capacity of that resource.
"""
function check_capacity(m::Map{A}) where A
    arch    = m.architecture
    edges   = m.mapping.edges

    times_resource_used = Dict{Any,Int}()
    resource_to_edge    = Dict{Any,Vector{Int}}()

    # categorize edges
    for (i,edge) in enumerate(edges)
        for v in vertices(edge)
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

Traverse the routing for each channel in `m.taskgraph`. Check:

* The nodes on each side of an edge in the routing graph are actually connected
    in the underlying architecture.
"""
function check_architecture_connectivity(m::Map{A}) where A
    # Get the edge mapping
    arch  = m.architecture
    edges = m.mapping.edges

    taskgraph_edges = getedges(m.taskgraph)

    success = true
    for (index, edge) in enumerate(edges)
        # Skip if edge did not need to be routed.
        needsrouting(A, taskgraph_edges[index]) || continue

        for i in vertices(edge), j in outneighbors(edge, i)
            if !isconnected(arch, i, j)
                success = false
            end
        end
    end
    return success
end

"""
    check_routing_connectivity(m::Map)

Perform the following check:

* Check that the routing graph for each channel in `m.taskgraph` is weakly 
    connected.
* Ensure there is a valid path from each source of the routing graph to each
    destination of the routing graph.
"""
function check_routing_connectivity(m::Map{A}) where A
    edges = m.mapping.edges

    taskgraph_edges = getedges(m.taskgraph)

    success = true
    # Construct a lightgraph from the sparsegraph
    for (i,edge) in enumerate(edges)
        # Skip edges that did not need to be routed.
        needsrouting(A, taskgraph_edges[i]) || continue

        g, d = make_lightgraph(edge)

        # Check for weakconnectivity
        if !is_weakly_connected(g)
            @error """
                Graph for edge number $i is not connected.
                """
            success = false
        end
        # Check paths from source to destination.
        sources = source_vertices(edge)
        sinks   = sink_vertices(edge)
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

"""
    check_architecture_resources(m::Map)

Traverse the routing graph for each channel in `m.taskgraph`. Check:

* The routing resources used by each channel are valid for that type of channel.
"""
function check_architecture_resources(m::Map{A}) where A
    edges = m.mapping.edges
    arch  = m.architecture

    success = true
    for (i, edge) in enumerate(edges)
        tg_edge = getedge(m.taskgraph, i) 
        for v in vertices(edge)
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
