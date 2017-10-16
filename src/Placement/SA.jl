#=
Simulated Annealing placement.
=#

################################################################################
# Type to keep track of previous moves.
################################################################################
abstract type AbstractCookie end
mutable struct MoveCookie{T,D} <: AbstractCookie
   cost_of_move            ::T
   index_of_moved_node     ::Int64
   move_was_swap           ::Bool
   index_of_other_node     ::Int64
   old_address             ::Address{D}
   old_component           ::Int64
end

MoveCookie{T,D}() where {T,D} = MoveCookie{T,D}(zero(T), 0, false, 0, Address{D}(), 0)

function place(
        sa::SAStruct#;
        #move_attempts = 5,
        #desired_acceptance_ratio = 0.40,
        #initial_acceptance_ratio = 0.7
       ) 

    move_attempts = 5
    desired_acceptance_ratio = 0.40
    initial_acceptance_ratio = 0.7

    # Unpack SA
    A = architecture(sa)
    D = dimension(sa)

    # Do some initial unpacking.
    num_nodes = length(sa.nodes)
    num_edges = length(sa.edges)
    move_attempts = move_attempts * ceil(Int64, num_nodes^(4/3))
    
    # Get the largest address
    max_addresses = Int16.(ind2sub(sa.component_table, endof(sa.component_table)))

    # Set up Simulated Annealing Parameters 
    largest_address = maximum(max_addresses)
    distance_limit  = Float64(largest_address)
    distance_limit_integer = floor(Int64, distance_limit)

    # Initialize tempearture and warming up boolean variable.
    T = 1.0
    warming = true

    # Performance counters
    performance_symbols = (:successful_moves, :total_moves)
    performance_counter = Dict(sym => 0 for sym in performance_symbols)

    # Initialize structure to help during placement.
    cost        = map_cost(A, sa)
    undo_cookie = MoveCookie{typeof(cost),D}()

    cost_history        = zeros(typeof(cost), 3)
    objective_is_stable = false

    progress_bar = ProgressThresh(0.0, "Running Simulated Annealing:")
    # Main Simulated Annealing Loop
    loop = true
    total_moves = 0
    while loop
        # Invert temperature to perform floating point multiplication rather
        # than division.
        one_over_T = 1 / T
        # Detect for stable objective, exit on next iteration.
        if !warming && objective_is_stable
            T = 0.0
            loop = false
            one_over_T = 2.0 ^ 20
        end
        accepted_moves = 0
        for i in 1:move_attempts
            # Try to generate a move. If it failed, try again.
            success = generate_move(A, sa, undo_cookie, 
                                    distance_limit_integer, max_addresses)
            success || continue
            total_moves += 1
            # Get the cost of the move
            cost_of_move = undo_cookie.cost_of_move

            if cost_of_move < 0 || rand() < exp(-cost_of_move * one_over_T)
               #performance_counter[:successful_moves] += 1
               accepted_moves += 1
               cost += cost_of_move
            else
               undo_move(sa, undo_cookie)
            end
        end

        # Post iteration routines
        cost = map_cost(A, sa)
        acceptance_ratio = accepted_moves / move_attempts
        if warming
            T *= 2
            if acceptance_ratio > initial_acceptance_ratio
                warming = false
                print_with_color(:red, "Done warming Up")
            end
        else
            T *= 0.9
        end
        temporary = (1 - desired_acceptance_ratio + acceptance_ratio)
        distance_limit = clamp(distance_limit * temporary, 1, largest_address)

        distance_limit_integer = max(round(Int16, distance_limit), 1)

        if DEBUG
            println()
            println("Temperature: ",T)
            println("Acceptance Ratio: ",acceptance_ratio)
            println("Total Moves: ", total_moves)
        end
        # Test to stable objectives
        for i = 1:length(cost_history)-1
           cost_history[i] = cost_history[i+1]
        end
        cost_history[end] = cost

        # Compute the max difference over the last update history
        max_diff = 0.0
        for i = 1:length(cost_history)-1
           max_diff = max(max_diff, abs(cost_history[i] - cost_history[i+1]))
        end

        # UPdate progress meter with the current average difference
        ProgressMeter.update!(progress_bar, max_diff / length(cost_history))

        # If the max difference is 0.0, meaning we've had a stable objective
        # over the last few iterations, set "objective_is_stable" = True to
        # break out of the loop.
        max_diff == 0.0 && (objective_is_stable = true)
    end
    println("Total Moves: ", total_moves)
    return total_moves
end

function move_with_undo(sa::SAStruct, undo_cookie, node::Int64, address, component)
    A = architecture(sa)
    # Store the old information
    undo_cookie.index_of_moved_node = node 
    undo_cookie.old_address = sa.nodes[node].address
    undo_cookie.old_component = sa.nodes[node].component
    # Check to see if there is a node already mapped to this location
    occupying_node = sa.grid[component, address]
    if occupying_node == 0
        undo_cookie.move_was_swap = false
        # Calculate move cost
        base_cost = node_cost(A, sa, node)
        # Move the node
        move(sa, node, component, address)
        # Get the new cost and store the cost of the move
        moved_cost = node_cost(A, sa, node)
        undo_cookie.cost_of_move = moved_cost - base_cost
    else
        # Indicate this move was a swap
        undo_cookie.move_was_swap = true
        # Save the index of the occupying node
        undo_cookie.index_of_other_node  = occupying_node
        # Compute the cost before the move
        base_cost = node_cost(A, sa, node) + node_cost(A, sa, occupying_node)
        # Swap nodes
        swap(sa, node, occupying_node)
        # Get cost after move and store
        moved_cost = node_cost(A, sa, node) + node_cost(A, sa, occupying_node)
        undo_cookie.cost_of_move = moved_cost - base_cost
    end
    return nothing
end

function undo_move(sa::SAStruct, undo_cookie)
    if undo_cookie.move_was_swap
        swap(sa, undo_cookie.index_of_moved_node, undo_cookie.index_of_other_node)
    else
        move(sa, undo_cookie.index_of_moved_node, 
             undo_cookie.old_component,
             undo_cookie.old_address)
    end
    return nothing
end
################################################################################
# DEFAULT MOVE GENERATION
################################################################################
canmove(::Type{A}, x) where {A <: AbstractArchitecture} = true

function generate_move(::Type{A}, sa::SAStruct, undo_cookie,
       distance_limit_integer, max_addresses) where {A <: AbstractArchitecture}

    # Pick a random node
    node = rand(1:length(sa.nodes)) 
    old_address = sa.nodes[node].address
    # Give a "canmove" function to allow certain nodes to be fixed if so
    # desired.
    canmove(A, sa.nodes[node]) || return false
    # Get the equivalent class of the node
    class = sa.nodeclass[node]
    # Get the address and component to move this node to
    local address::Address{dimension(sa)}
    if class > 0
        address = standard_move(
            A, sa, old_address, class, distance_limit_integer, max_addresses
         )
        length(sa.maptables[class][address]) == 0 && return false
        component = rand(sa.maptables[class][address])
    else
        address = special_move(
            A, sa, class
         )
        component = rand(sa.special_maptables[-class][address])
    end
    # Perform the move and record enough information to undo the move
    move_with_undo(sa::SAStruct, undo_cookie, node, address, component) 

    return true
end

function standard_move(::Type{A}, 
                       sa::SAStruct, 
                       address,
                       class, 
                       distance_limit_integer, 
                       max_addresses)::Address{dimension(sa)} where {A <: AbstractArchitecture}
    D = dimension(sa) 
    # Generate a new address based on the distance limit
    move_ub = Int16.(min.(address.addr .+ distance_limit_integer, max_addresses))
    move_lb = Int16.(max.(address.addr .- distance_limit_integer, 1))
    new_address = Address{D}((rand(move_lb[i]:move_ub[i]) for i in 1:D)...)
    return new_address
end

function special_move(::Type{A}, 
                      sa::SAStruct, 
                      class) where {A <: AbstractArchitecture}
    # Get the special address table for this class.
    new_address = rand(sa.special_addresstables[-class])::Address{dimension(sa)}
    return new_address
end

