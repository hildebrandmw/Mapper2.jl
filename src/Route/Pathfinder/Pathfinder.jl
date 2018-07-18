struct CostVertex
   cost :: Float64
   index :: Int64
   predecessor :: Int64
end
CostVertex(index::Int64) = CostVertex(0.0, index, -1)
Base.isless(a::CostVertex, b::CostVertex) = a.cost < b.cost

mutable struct Pathfinder{A,T,Q} <: AbstractRoutingAlgorithm
    historical_cost :: Vector{Float64}
    congestion_cost_factor :: Float64
    historical_cost_factor :: Float64
    iteration_limit :: Int64
    links_to_route :: T
    # Scratch-pad to avoid re-allocation.
    discovered  :: BitVector
    predecessor :: Vector{Int64}
    pq          :: Q

    # Constructor
    function Pathfinder(m::Map{A}, rs::RoutingStruct) where A
        rg = getgraph(rs)
        num_vertices = nv(rg.graph)
        # Initialize a vector with the number of vertices in the routing resouces
        # graph.
        historical_cost = ones(Float64, num_vertices)
        congestion_cost_factor = 3.0
        historical_cost_factor = 3.0
        iteration_limit = 100
        links_to_route = 1:length(rs.channels)

        # Initialized all nodes as undiscovered
        discovered  = falses(num_vertices)
        # Initially, all nodes have no predecessors. The initial state of this
        # structure should be cleared to the correct default values.
        predecessor = zeros(Int64, num_vertices)
        pq          = binary_minheap(CostVertex)

        return new{A,typeof(links_to_route),typeof(pq)}(
            historical_cost,
            congestion_cost_factor,
            historical_cost_factor,
            iteration_limit,
            links_to_route,
            # scratchpad
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
function links_to_route(p::Pathfinder, r::RoutingStruct, iteration)
    # Every so many iterations, reset the entire routing process to help
    # global convergence.
    # if mod(iteration,50) == 1
    #     iter = collect(p.links_to_route)
    # else
    #     iter = [link for link in p.links_to_route if iscongested(r,link)]
    # end
    iter = collect(p.links_to_route)

    lt = (x,y) -> isless(getchannel(r, x), getchannel(r, y))
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
    p = 1 + max(0, pf.congestion_cost_factor * (1 + occupancy(link) - capacity(link)))

    h = pf.historical_cost[index]
    return base_cost * p * h
end

function currentcost(pathfinder, routing_struct, link_idx)
    link = getlink(routing_struct, link_idx)
    base_cost = cost(link)
    p = 1 + max(0, pathfinder.congestion_cost_factor * (occupancy(link) - capacity(link)))

    return base_cost * p
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

function routecost(
        pathfinder::Pathfinder, 
        routing_struct::RoutingStruct,
        channel_idx :: Integer
    )

    cost = zero(Float64)
    for link_idx in vertices(getroute(routing_struct, channel_idx))
        thiscost = currentcost(pathfinder, routing_struct, link_idx)
        if thiscost > 1E6
            @show link_idx
            link = getlink(routing_struct, link_idx)
            @show occupancy(link)
            @show capacity(link)
        end
        cost += thiscost
    end
    return cost
end

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
    graph       = getgraph(r).graph
    pq          = p.pq
    discovered  = p.discovered
    predecessor = p.predecessor
    # Add all the start nodes to the priority queue.
    start_vectors = start_vertices(r, channel)

    if length(start_vectors) > 1
        throw(ErrorException("""
            Pathfinder cannot run for channels with more than one source component.
            """))
    end
    # Iterate through the list of possible starting points for this channel and
    # add it to the priority queue.
    for node in shuffle(first(start_vectors))
        push!(pq, CostVertex(node))
    end

    task = getchannel(r, channel)

    # Get the stop nodes for this channel
    stop_vectors = stop_vertices(r, channel)
    stop_mask    = trues(length(stop_vectors))

    # Path type that we will store the final paths in.
    paths = SparseDiGraph{Int64}()

    # Keep iterating until all destination nodes have been reached.
    while count(stop_mask) > 0
        # Empty the priority queue
        soft_reset(p)

        # Get the start nodes. If this is the first iteration, get the start
        # nodes from the data structure definition. Otherwise, use the previously
        # used nodes in "paths" as the starting points
        if nv(paths) == 0
            startnodes = shuffle(first(start_vectors))
            for i in startnodes
                push!(pq, CostVertex(i))
            end
        else
            startnodes = Int64[]
            for j in vertices(paths) 
                discovered[j] = true
                # Add all the neighbors of these nodes to the priority queue.
                for u in outneighbors(graph, j)
                    link = getlink(r,u)
                    if !discovered[u] && canuse(A, link, task)
                        new_cost = linkcost(p,r,u)
                        push!(pq, CostVertex(new_cost,u,j))
                    end
                end
                push!(startnodes, j)
            end
        end

        # Get the stop nodes from the undiscovered destinations.
        # Iterate through the vector{vector{int}}, skipping if the destination
        # has already been found.
        stopnodes = Int64[]
        for i in eachindex(stop_vectors)
            stop_mask[i] || continue
            append!(stopnodes, stop_vectors[i])
        end

        # Initialize search variables
        lastnode  = 0
        success   = false
        while !isempty(pq)
            # Pop a node out of the priority queue
            v = pop!(pq)
            # Check if this node is one of the stop nodes. If so - exit the loop.
            if in(v.index, stopnodes)
                lastnode = v.index
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
            for u in outneighbors(graph, v.index)
                link_type = getlink(r,u)
                if !discovered[u] && canuse(A, link_type, task)
                    # Compute the cost of taking the new vertex and add it
                    # to the queue.
                    new_cost = v.cost + linkcost(p,r,u)
                    push!(pq, CostVertex(new_cost,u,v.index))
                end
            end
        end

        if success == false
            throw(ErrorException("Shortest Path failed on channel index $channel."))
        end
        # Do a back-trace from the last vertex to determine the path that
        # this connection took through the graph.
        add_vertex!(paths, lastnode)

        i = lastnode
        j = predecessor[i]
        # Iterate until we find a start node.
        while j != -1
            add_vertex!(paths, j) 
            add_edge!(paths, j, i)
            i, j = j, predecessor[j]
        end

        # Now, find which destination was reached, and mark it as completed
        found_vector = false
        for i in eachindex(stop_vectors)
            stop_mask[i] || continue
            # Check to see if the last discovered node is in this collection
            if in(lastnode, stop_vectors[i])
                stop_mask[i] = false
                found_vector = true
                break
            end
        end

        # Error checking
        if found_vector == false
            throw(ErrorException("""
                Final Node $previous_index is not a valid stop node.
                """))
        end
    end
    # Wrap the path in an edge path and add it to the RoutingStruct.
    setroute(r, paths, channel)
    return nothing
end

function route(p::Pathfinder, rs::RoutingStruct)
    iterations_per_update = 10
    num_congested_links = 0

    @info "Running Pathfinder Routing Algorithm"
    for i in 1:p.iteration_limit
        # Rip up all routes
        for link in links_to_route(p, rs, i)
            clear_route(rs, link)
        end

        # Run routing
        for link in links_to_route(p, rs, i)
            shortest_path(p, rs, link)
        end
        update_historical_congestion(p, rs)
        num_congested_links = 0
        # Count the number of congested links.
        for j in p.links_to_route
            if iscongested(rs, j)
                num_congested_links += 1
            end
        end

        # Report status update.
        if mod(i, iterations_per_update) == 0
            # Report the number of congested links.
            @info """
                On iteration $i of $(p.iteration_limit).
                Number of congested links: $num_congested_links.
                """
            # If congestion is extremely bad, further routings will be super
            # slow. If over 90% of the links are congested, it's very likely
            # that the placement is uunroutable. Just abort early.
            if num_congested_links > 0.9 * length(p.links_to_route)
                @warn "Warning. Extreme congestion detected - aborting early."
                break
            end
        end
        num_congested_links == 0 && break
    end

    # Perform cleanup if not congested
    if num_congested_links == 0
        cleanup(p, rs)
    end
    return nothing
end

"""
    cleanup(pathfinder)

Post Pathfinder algorithm cleanup routine. Removes historical congestion and
tries to reroute links. Will only accept a new routing if it decreases the
total number of links. Congestion will not be allowed during this phase, so 
it can only improve routing quality.

Cleanup process will continue until no improvement it seen.
"""
function cleanup(pathfinder :: Pathfinder, routing_struct :: RoutingStruct)
    # Set the historical_cost_factor to zero to essentially remove its impact.
    pathfinder.historical_cost_factor = 0.0
    pathfinder.historical_cost .= 1

    # Set the congestion_cost_factor to a large number so congested routes become
    # very sternly discouraged
    pathfinder.congestion_cost_factor = 1.0E6

    # Reroute each link.
    while true
        @debug "Running Cleanup"
        cost_decreased = false
        for channel_idx in pathfinder.links_to_route
            # Get initial cost of the channel.
            initial_cost = routecost(pathfinder, routing_struct, channel_idx)

            # Save the old routing
            old_routing = getroute(routing_struct, channel_idx)

            # Ripup and reroute
            clear_route(routing_struct, channel_idx)
            shortest_path(pathfinder, routing_struct, channel_idx)

            # Process the final cost.
            final_cost = routecost(pathfinder, routing_struct, channel_idx)

            # @show initial_cost
            # @show final_cost

            if final_cost < initial_cost
                @debug final_cost - initial_cost
                cost_decreased = true
            end
        
        end

        # Exit when cost stops decreasing.
        cost_decreased || break
    end
    return nothing
end
