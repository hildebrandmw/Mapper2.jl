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

################################################################################
# Structure to keep track of performance information
################################################################################
const SAStateUpdateInterval = 1
mutable struct SAState
    #= Information related to most recent move attempt =#
    "Current Temperature of the system"
    temperature         ::Float64
    "Current objective value"
    objective           ::Float64
    "Current Distance Limit"
    distance_limit      ::Float64

    "Current number of move attempts"
    recent_move_attempts    ::Int64
    recent_successful_moves ::Int64
    recent_accepted_moves   ::Int64

    "Current Warming State"
    warming             ::Bool

    #= Global state information =#
    "Total number of move attempts made"
    total_moves::Int64
    "Number of successful move generations"
    successful_moves::Int64
    "Number of moves accepted"
    accepted_moves::Int64
    "Moves per second"
    moves_per_second::Float64
    "Creation time of the structure"
    start_time::Float64
    #= Methods for dealing with the updates =#
    "Time of the last update"
    last_update_time::Float64
    "Update Interval"
    dt::Float64
    function SAState(temperature, distance_limit, objective)
        return new(
            # Most recent run
            temperature,        # temperature
            Float64(objective), # objective
            distance_limit,     # distance_limit
            0,                  # recent_move_attempts
            0,                  # recent_successful_moves
            0,                  # recent_accepted_moves
            true,               # warming

            # Global run
            0,  # total_moves
            0,  # suffessful_moves
            0,  # accepted_moves
            0.0,# moves_per_second
            time(), # creation time

            # Update parameters
            time(),                     # Time of creation
            SAStateUpdateInterval,      # Default update interval
         )
    end
end

function update!(state::SAState)
    # Update the global counters
    state.total_moves       += state.recent_move_attempts
    state.successful_moves  += state.recent_successful_moves
    state.accepted_moves    += state.recent_accepted_moves
    # Compute number of moves per second.
    state.moves_per_second = state.successful_moves / (time() - state.start_time) 
    # Determine whether or not to print out results
    if DEBUG 
        current_time = time()
        #println(state.dt)
        #println(current_time - state.last_update_time)
        #println()
        if current_time > state.last_update_time + state.dt
            println(state)
            state.last_update_time = time()
        end
    end
    return nothing
end


################################################################################
# Placement Routine!
################################################################################

function place(
        sa::SAStruct#;
       )

    move_attempts = 5000
    # Unpack SA
    A = architecture(sa)
    D = dimension(sa)

    # Do some initial unpacking.
    num_nodes = length(sa.nodes)
    num_edges = length(sa.edges)
    
    # Get the largest address
    max_addresses = ind2sub(sa.component_table, endof(sa.component_table))

    # Set up Simulated Annealing Parameters 
    largest_address = maximum(max_addresses)

    # Initialize structure to help during placement.
    cost = map_cost(A, sa)
    undo_cookie = MoveCookie{typeof(cost),D}()

    # Main Simulated Annealing Loop
    loop = true

    # Start timer here - useful for printing debug information.
    # Initialize tempearture and warming up boolean variable.
    state = SAState(1.0, Float64(largest_address), cost)
    while loop
        # Invert temperature to perform floating point multiplication rather
        # than division. Set local counters for this iteration.
        one_over_T = 1 / state.temperature
        accepted_moves      = 0
        successful_moves    = 0
        objective           = state.objective
        distance_limit      = max(round(state.distance_limit), 1)
        # Inner Loop
        for i in 1:move_attempts
            # Try to generate a move. If it failed, try again.
            generate_move(A, sa, undo_cookie, distance_limit, max_addresses) || continue
            successful_moves += 1
            # Get the cost of the move
            cost_of_move = undo_cookie.cost_of_move
            if cost_of_move < 0 || rand() < exp(-cost_of_move * one_over_T)
               accepted_moves += 1
               objective += cost_of_move
            else
               undo_move(sa, undo_cookie)
            end
        end

        ###########################
        # Post iteration routines #
        ###########################
        # Update cost for numerical stability reasons
        state.objective = map_cost(A, sa)
        #@assert objective == state.objective
        # Update some statistice in the state variable 
        state.recent_move_attempts      = move_attempts
        state.recent_successful_moves   = successful_moves
        state.recent_accepted_moves     = accepted_moves

        # Adjust temperature
        state.warming ? warm(state) : cool(state)
    #    update_limit(state)


        # TODO: Clean this up
        # Compute the new distance limit
        desired_acceptance_ratio = 0.44
        # Acceptance ratio
        acceptance_ratio = state.recent_accepted_moves /
                           state.recent_move_attempts

        temporary = (1 - desired_acceptance_ratio + acceptance_ratio)
        state.distance_limit = clamp(state.distance_limit * temporary, 
                                     1, 
                                     largest_address)

        # State updates
        update!(state)
        state.total_moves == 10_000_000 && (loop = false)
    end
    return state
end

################################################################################
# Default state-changing functions
################################################################################
@inline function warm(state::SAState)
    # Acceptance ratio
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_move_attempts

    state.temperature *= 2
    # Check if we're at the desired acceptance ratio, if so, end the
    # warming up procedure.
    initial_acceptance_ratio = 0.7
    if acceptance_ratio > initial_acceptance_ratio
        state.warming = false
    end
end

@inline cool(state::SAState) = (state.temperature *= 0.992)

function update_limit(state::SAState)
    # Compute the new distance limit
    desired_acceptance_ratio = 0.44
    # Acceptance ratio
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_move_attempts

    temporary = (1 - desired_acceptance_ratio + acceptance_ratio)
    state.distance_limit = round(Int64, clamp(state.distance_limit * temporary, 1, largest_address))
end

################################################################################
# Movement related functions
################################################################################

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
       distance_limit, max_addresses) where {A <: AbstractArchitecture}

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
            A, sa, old_address, class, distance_limit, max_addresses
         )
        maptable = sa.maptables[class]
        length(maptable[address]) == 0 && return false
        component = rand(maptable[address])
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
    # Generate a new address based on the distance limit
    move_ub = min.(address.addr .+ distance_limit_integer, max_addresses)
    move_lb = max.(address.addr .- distance_limit_integer, 1)
    new_address = rand_address(move_lb, move_ub)
    return new_address
end

function special_move(::Type{A}, 
                      sa::SAStruct, 
                      class) where {A <: AbstractArchitecture}
    # Get the special address table for this class.
    new_address = rand(sa.special_addresstables[-class])::Address{dimension(sa)}
    return new_address
end

