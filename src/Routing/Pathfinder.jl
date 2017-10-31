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

mutable struct Pathfinder{T,Q} <: AbstractRoutingAlgorithm
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
end

function Pathfinder(m::Map{A,D}, rs::RoutingStruct) where {A <: AbstractArchitecture, D}
    rg = rs.resources_graph
    num_vertices = nv(rg.graph)
    # Initialize a vector with the number of vertices in the routing resouces
    # graph.
    historical_cost         = ones(Float64, num_vertices)
    current_cost_factor     = 2.0
    historical_cost_factor  = 2.0
    iteration_limit         = 100
    links_to_route = 1:num_edges(m.taskgraph)
    # Runtime Structures
    discovered  = falses(num_vertices)
    predecessor = zeros(Int64, num_vertices)
    pq = binary_minheap(CostVertex)

    return Pathfinder(
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
    # Reset the runtime structures.
    soft_reset(p)
    # Unpack the certain variables.
    graph       = rs.resources_graph.graph
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
        if !discovered[v.index]
            discovered[v.index] = true
            predecessor[v.index] = v.predecessor
            for u in out_neighbors(graph, v.index)
                if !discovered[u] && canuse(rs, u, link)
                    # Compute the cost of taking the new vertex and add it
                    # to the queue.
                    new_cost = v.cost + nodecost(p,rs,u)
                    push!(pq, CostVertex(new_cost,u,v.index))
                end
            end
        end
    end
    # Raise an error if routing was not successful
    success || error()
    # Do a back-trace from the last vertex to determine the path that
    # this connection took through the graph.
    path = [previous_index]
    # Iterate until we find a start node.
    while !in(path[end], startnodes)
        push!(path, predecessor[path[end]])
    end
    # Wrap the path in an edge path and add it to the RoutingStruct.
    set_route(rs, EdgePath(path), link)
    return nothing
end

function route(p::Pathfinder, rs::RoutingStruct)
    DEBUG && print_with_color(:cyan, "Running Pathfinder Routing Algorithm.\n")
    for i in 1:p.iteration_limit
        rip_up_routes(p, rs)
        for link in shuffle(p.links_to_route)
            shortest_path(p, rs, link)
        end
        update_historical_congestion(p, rs)
        # Debug Update
        if DEBUG
            print_with_color(:yellow,"On iteration: ")
            print(i)
            print_with_color(:yellow, " of ")
            println(p.iteration_limit)
            # Print out the number of congested paths
            congested_links = Int64[]
            for i in  p.links_to_route
                if iscongested(rs, i)
                    push!(congested_links, i)
                end
            end
            print_with_color(:red, "Number of Congested Links: ")
            println(length(congested_links))
        end

        iscongested(rs) || break
    end
    return nothing
end

