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

    # Constructor
    function Pathfinder(m::Map{A,D}, rs::RoutingStruct) where {A <: AbstractArchitecture, D}
        rg = rs.graph
        num_vertices = nv(rg.graph)
        # Initialize a vector with the number of vertices in the routing resouces
        # graph.
        historical_cost         = ones(Float64, num_vertices)
        current_cost_factor     = 3.0
        historical_cost_factor  = 3.0
        iteration_limit         = 200
        links_to_route = 1:num_edges(m.taskgraph)

        #=
        Runtime Structures

        Put in this structure to avoid reallocation for each invocation of the
            Pathfinder Algorithm
        =#

        # Initialized all nodes as undiscovered
        discovered  = falses(num_vertices)
        # Initially, all nodes have no predecessors. The initial state of this
        # structure should be cleared to the correct default values.
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

"Return the Architecture type for the given Pathfinder structure."
getarchitecture(::Pathfinder{A,T,Q}) where {A,T,Q} = A


"""
    links_to_route(p::Pathfinder, routing_struct, iteration)

Return an iterator of links to route given the `Pathfinder` state, the
`RoutingStruct`, and the `iteration` number.
"""
function links_to_route(p::Pathfinder, r, iteration)
    # Every so many iterations, reset the entire routing process to help
    # global convergence.
    if mod(iteration,50) == 1
        iter = collect(p.links_to_route)
    else
        iter = [link for link in p.links_to_route if iscongested(r,link)]
    end
    # Sort according to relationship among routing taskgraph nodes.
    lt = ((x,y) -> isless(getchannel(r,x), getchannel(r,y)))
    sort!(iter, lt = lt)

    return iter
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
    rip_up_routes(p::Pathfinder, rs::RoutingStruct)

Rip up all the routes.
"""
function rip_up_routes(p::Pathfinder, rs::RoutingStruct)
    for link in p.links_to_route
        clear_route(rs, link)
    end
end


"""
    linkcost(pf::Pathfinder, rs::RoutingStruct, node::Integer)

Return the cost of a routing resource `node` for the current routing state.
"""
function linkcost(pf::Pathfinder, rs::RoutingStruct, index::Integer)
    # Get the link info from the routing structure.
    link = getlink(rs, index)
    base_cost = cost(link)
    # Compute the penalty for present congestion
    p = 1 + max(0, pf.current_cost_factor * (1 + occupancy(link) - capacity(link)))
    h = pf.historical_cost[index]
    return base_cost * p * h
end

function update_historical_congestion(p::Pathfinder, rs::RoutingStruct)
    for i in eachindex(p.historical_cost)
        link = getlink(rs, i)
        overflow = p.historical_cost_factor * (occupancy(link) - capacity(link))
        if overflow > 0
            p.historical_cost[i] += overflow
        end
    end
    return nothing
end

const debug = []

"""
    shortest_path(p::Pathfinder, r::RoutingStruct, channel::Integer)

Run weighted shortest path routing computation on the routing structure given
the current `Pathfinder` state.
"""
function shortest_path(p::Pathfinder, r::RoutingStruct, channel::Integer)
    A = getarchitecture(p)
    # Reset the runtime structures.
    soft_reset(p)
    # Unpack the certain variables.
    graph       = r.graph.graph
    pq          = p.pq
    discovered  = p.discovered
    predecessor = p.predecessor
    # Add all the start nodes to the priority queue.
    startnodes = shuffle(start(r, channel))
    for i in startnodes
        push!(pq, CostVertex(0.0, i, -1))
    end
    # Get the stop nodes for this channel
    stopnodes = stop(r, channel)

    task = getchannel(r, channel)

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
        # Mark node as discovered and all undiscovered neighbors.
        discovered[v.index] = true
        predecessor[v.index] = v.predecessor
        for u in out_neighbors(graph, v.index)
            link_type = getlink(r,u)
            if !discovered[u] && canuse(A, link_type, task)
                # Compute the cost of taking the new vertex and add it
                # to the queue.
                new_cost = v.cost + linkcost(p,r,u)
                push!(pq, CostVertex(new_cost,u,v.index))
            end
        end
    end
    # Raise an error if routing was not successful
    if !success
        empty!(debug)
        push!(debug, p)
        push!(debug, r)
        push!(debug, channel)
        error("Shortest Path failed epicly on link: $channel.")
    end
    # Do a back-trace from the last vertex to determine the path that
    # this connection took through the graph.
    path = [previous_index]
    # Iterate until we find a start node.
    while !in(first(path), startnodes)
        unshift!(path, predecessor[first(path)])
    end
    # Wrap the path in an edge path and add it to the RoutingStruct.
    set_route(r, ChannelPath(path), channel)
    return nothing
end

function route(p::Pathfinder, rs::RoutingStruct)
    @info "Running Pathfinder Routing Algorithm"
    for i in 1:p.iteration_limit
        for link in links_to_route(p,rs,i)
            clear_route(rs, link)
            shortest_path(p, rs, link)
        end
        update_historical_congestion(p, rs)
        ncongested = 0
        # Count the number of congested links.
        for i in p.links_to_route
            if iscongested(rs, i)
                ncongested += 1
            end
        end
        # Debug update
        @debug """
            On iteration $i of $(p.iteration_limit).
            Number of congested links: $ncongested.
            """
        ncongested == 0 && break
    end
    return nothing
end

