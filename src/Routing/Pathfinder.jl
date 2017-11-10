#=
A flexible structure used to launch the pathfinder algorithm.

May be used as a whole routing structure or a sub-structure for routing problems
with multiple networks.
=#

struct CostVertex
   cost        ::Float64
   index       ::Int64
   predecessor ::Int64
end
Base.isless(a::CostVertex, b::CostVertex) = a.cost < b.cost
#Base.==(a::CostVertex, b::CostVertex) = a.cost == b.cost

mutable struct Pathfinder{A,T,Q} <: AbstractRoutingAlgorithm
    """
    The present and historical link costs.
    """
    historical_cost         ::Vector{Float64}
    current_cost_factor     ::Float64
    historical_cost_factor  ::Float64
    iteration_limit         ::Int64
    links_to_route          ::T
    # Structures used during the pathfinder algorithm. Keep them here to
    # avoid re-allocation every time.
    discovered  ::BitVector
    predecessor ::Vector{Int64}
    pq          ::Q
    function Pathfinder(m::Map{A,D}, rs::RoutingStruct) where {A <: AbstractArchitecture, D}
        rg = rs.resource_graph
        num_vertices = nv(rg.graph)
        # Initialize a vector with the number of vertices in the routing resouces
        # graph.
        historical_cost         = ones(Float64, num_vertices)
        current_cost_factor     = 3.0
        historical_cost_factor  = 3.0
        iteration_limit         = 200
        links_to_route = 1:num_edges(m.taskgraph)
        # Runtime Structures
        discovered  = falses(num_vertices)
        predecessor = zeros(Int64, num_vertices)
        pq = binary_minheap(CostVertex)

        return new{A,typeof(links_to_route),typeof(pq)}(
            historical_cost,
            current_cost_factor,
            historical_cost_factor,
            iteration_limit,
            links_to_route,
            # runtime structures
            discovered,
            predecessor,
            pq,)
    end
end

getarchitecture(::Pathfinder{A,T,Q}) where {A,T,Q} = A

function links_to_route(p::Pathfinder, rs, i)
    # Every so many iterations, reset the entire routing process to help
    # global convergence.
    if mod(i,50) == 1
        return collect(p.links_to_route)
    else
        return [link for link in p.links_to_route if iscongested(rs,link)]
    end
end

"""
    soft_reset(p::Pathfinder)

Reset the run-time structures in `p`.
"""
function soft_reset(p::Pathfinder)
    # Zero out the discovered vector.
    p.discovered .= false 
    # Empty out the priority queue.
    while !isempty(p.pq)
        pop!(p.pq)
    end
    return nothing
end

"""
    rip_up_routes(p, rs)

Rip up all the routes.
"""
function rip_up_routes(p::Pathfinder, rs::RoutingStruct)
    for link in p.links_to_route
        clear_route(rs, link) 
    end
end

function nodecost(pf::Pathfinder, rs::RoutingStruct, node::Integer)
    # Get the link info from the routing structure.
    link = get_link_info(rs, node)
    base_cost = getcost(link)
    # Compute the penalty for present congestion
    p = 1 + max(0, pf.current_cost_factor * (1 + getoccupancy(link) - getcapacity(link)))
    h = pf.historical_cost[node]
    cost = base_cost * p * h
    return cost
end

function update_historical_congestion(p::Pathfinder, rs::RoutingStruct)
    for i in eachindex(p.historical_cost)
        link = get_link_info(rs, i)
        overflow = p.historical_cost_factor * (getoccupancy(link) - getcapacity(link))
        if overflow > 0
            p.historical_cost[i] += overflow
        end
    end
    return nothing
end

function shortest_path(p::Pathfinder, rs::RoutingStruct, link::Integer)
    A = getarchitecture(p)
    # Reset the runtime structures.
    soft_reset(p)
    # Unpack the certain variables.
    graph       = rs.resource_graph.graph
    pq          = p.pq
    discovered  = p.discovered
    predecessor = p.predecessor
    # Add all the start nodes to the priority queue.
    startnodes = shuffle(start_nodes(rs, link))
    for i in startnodes
        push!(pq, CostVertex(0.0, i, -1))
    end
    # Get the stop nodes for this link
    stopnodes = stop_nodes(rs, link)

    previous_index = 0
    success = false
    while !isempty(pq)
        # Pop a node out of the priority queue
        v = pop!(pq)
        # Check if this node is one of the stop nodes. If so - exit the loop. 
        if in(v.index, stopnodes)
            previous_index = v.index
            predecessor[v.index] = v.predecessor
            success = true
            break
        end
        # If the node has not been discovered yet - mark it as discovered and
        # mark its predecessor for a potential backtrace. Add all neighbors
        # of this node to the queue.
        discovered[v.index] && continue
        # Mark node as discovered and all all undiscovered neighbors.
        discovered[v.index] = true
        predecessor[v.index] = v.predecessor
        for u in out_neighbors(graph, v.index)
            if !discovered[u] && canuse(A, rs, u, link)
                # Compute the cost of taking the new vertex and add it
                # to the queue.
                new_cost = v.cost + nodecost(p,rs,u)
                push!(pq, CostVertex(new_cost,u,v.index))
            end
        end
    end
    # Raise an error if routing was not successful
    success || error("Shortest Path failed epically.")
    # Do a back-trace from the last vertex to determine the path that
    # this connection took through the graph.
    path = [previous_index]
    # Iterate until we find a start node.
    while !in(first(path), startnodes)
        unshift!(path, predecessor[first(path)])
    end
    # Wrap the path in an edge path and add it to the RoutingStruct.
    set_route(rs, EdgePath(path), link)
    return nothing
end

function route(p::Pathfinder, rs::RoutingStruct)
    DEBUG && print_with_color(:cyan, "Running Pathfinder Routing Algorithm.\n")
    for i in 1:p.iteration_limit
        for link in links_to_route(p,rs,i)
            clear_route(rs, link)
            shortest_path(p, rs, link)
        end
        update_historical_congestion(p, rs)
        # Debug Update
        if DEBUG
            debug_print(:info,"On iteration: ")
            debug_print(:none, i)
            debug_print(:info, " of ")
            debug_print(:none, p.iteration_limit, "\n")
            # Print out the number of congested paths
            congested_links = Int64[]
            for i in p.links_to_route
                if iscongested(rs, i)
                    push!(congested_links, i)
                end
            end
            if length(congested_links) > 0
                debug_print(:warning, "Number of Congested Links: ")
                debug_print(:none,length(congested_links), "\n")
            end
        end

        iscongested(rs) || break
    end
    return nothing
end

