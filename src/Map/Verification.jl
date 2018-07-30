passfail(b) = b ? "passed" : "failed"

################################################################################
# Routing Checks
################################################################################
"""
$(SIGNATURES)

Check routing in `map`. Return `true` if `map` passes all checks. Otherwise,
return `false`. If `quiet = false`, print status of each test to `STDOUT`.

Checks performed:

* [`check_placement`](@ref)
* [`check_ports`](@ref)
* [`check_capacity`](@ref)
* [`check_architecture_connectivity`](@ref)
* [`check_routing_connectivity`](@ref)
* [`check_architecture_resources`](@ref)
"""
function check_routing(map::Map; quiet = false)
    placement_okay  = check_placement(map)
    port_okay       = check_ports(map)
    capacity_okay   = check_capacity(map)
    graph_okay      = check_routing_connectivity(map)
    arch_okay       = check_architecture_connectivity(map)
    resource_okay   = check_architecture_resources(map)

    if !quiet
        @info """
            Routing Summary
            ---------------
            Placement Check:    $(passfail(placement_okay))
            Congestion Check:   $(passfail(capacity_okay))
            Port Check:         $(passfail(port_okay))
            Graph Connectivity: $(passfail(graph_okay))
            Architecture Check: $(passfail(arch_okay))
            Resource Check:     $(passfail(resource_okay))
            """
    end

    return all((
        placement_okay, 
        capacity_okay, 
        port_okay, 
        graph_okay, 
        arch_okay, 
        resource_okay
    ))
end


"""
$(SIGNATURES)

Ensure that each [`TaskgraphNode`](@ref) is mapped to a valid component.
"""
function check_placement(map::Map)
    pass = true
    # Iterate through all tasks in the taskgraph. Get the component they are 
    # mapped to and call "canmap".
    for (name, node) in map.taskgraph.nodes
        path = getpath(map, name)
        component = map.toplevel[path]

        if !canmap(rules(map), node, component)
            @error """
                TaskgraphNode $(node.name) cannot be mapped to component $path.
                """
            pass = false
        end
    end

    return pass
end

"""
    check_ports(m::Map{A}) where A

Check the source and destination ports for each task in `m`. Perform the 
following checks:

* Each source and destination port for each task channel is valid.
* All sources and destinations for each task channel has been assigned to
    a port.
"""
function check_ports(map::Map)
    edges = map.mapping.edges
    toplevel  = map.toplevel
    taskgraph    = map.taskgraph

    taskgraph_edges = getedges(taskgraph)

    success = true
    for (i,routing_graph) in enumerate(edges)
        # Skip this edge if it wasn't supposed to be routed.
        needsrouting(rules(map), taskgraph_edges[i]) || continue

        # Get the taskgraph sources and sinks
        channel = getedge(taskgraph, i) 

        taskgraph_sources = getsources(channel)
        taskgraph_sinks   = getsinks(channel)

        routing_sources = Set(source_vertices(routing_graph))
        routing_sinks   = Set(sink_vertices(routing_graph))

        # Check that source ports are valid for the location of the placed tasks.
        for source in taskgraph_sources
            # Get the mapped component path
            sourcepath = getpath(map, source)
            found = false
            for rs in routing_sources
                if striplast(rs) == sourcepath && is_source_port(rules(map), toplevel[rs], channel)
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
            sinkpath = getpath(map, sink)
            found = false
            for rs in routing_sinks
                if striplast(rs) == sinkpath && is_sink_port(rules(map), toplevel[rs], channel)
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

* The number of channels assigned to each routing resource in `m.toplevel`
    does not exceed the stated capacity of that resource.
"""
function check_capacity(m::Map)
    toplevel    = m.toplevel
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
        if occupancy > getcapacity(rules(m), toplevel[path])
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
function check_architecture_connectivity(m::Map)
    # Get the edge mapping
    toplevel  = m.toplevel
    edges = m.mapping.edges

    taskgraph_edges = getedges(m.taskgraph)

    success = true
    for (index, edge) in enumerate(edges)
        # Skip if edge did not need to be routed.
        needsrouting(rules(m), taskgraph_edges[index]) || continue

        for i in vertices(edge), j in outneighbors(edge, i)
            if !isconnected(toplevel, i, j)
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
function check_routing_connectivity(m::Map)
    edges = m.mapping.edges

    taskgraph_edges = getedges(m.taskgraph)

    success = true
    # Construct a lightgraph from the sparsegraph
    for (i,edge) in enumerate(edges)
        # Skip edges that did not need to be routed.
        needsrouting(rules(m), taskgraph_edges[i]) || continue

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
    check_architecture_resources(map::Map)

Traverse the routing graph for each channel in `m.taskgraph`. Check:

* The routing resources used by each channel are valid for that type of channel.
"""
function check_architecture_resources(map::Map)
    mapping_edges = map.mapping.edges
    toplevel = map.toplevel

    success = true
    for (i, mapping_edge) in enumerate(mapping_edges)
        taskgraph_edge = getedge(map.taskgraph, i) 
        for v in vertices(mapping_edge)
            # Checking routing
            if !canuse(rules(map), toplevel[v], taskgraph_edge)
                success = false
                @error """
                    Taskgraph edge number $i can not use resource $v. 
                    """
            end
        end
    end
    return success
end
