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
# Types that control various parameters of the placement.
################################################################################

# Warming schedules
abstract type AbstractSAWarm end
"""
Default warming schedule. On each invocation, will increase the temperature of
the anneal by `multiplier`. When the acceptance ratio rises above `ratio`, 
warming routine will end.

To prevent unbounded warming, the `ratio` field is multiplier by the `decay`
field on each invocation.
"""
mutable struct DefaultSAWarm <: AbstractSAWarm
    ratio       ::Float64
    multiplier  ::Float64
    decay       ::Float64
end

# Cooling Schedules
abstract type AbstractSACool end
"""
Default cooling schedule. Each invocation, will multipkly the temperature
of the anneal by the `alpha` paramter.
"""
struct DefaultSACool <: AbstractSACool
    alpha::Float64
end

# Distance limit updates
abstract type AbstractSALimit end
"""
Default deistnace limit updater. Will adjust the distance limit so approximate
`ratio` of moves are accepted. See VPR for algorithm.
"""
struct DefaultSALimit <: AbstractSALimit
    ratio       ::Float64
end

# Finishing Schedules
abstract type AbstractSADone end
"""
Default end detection. Will return `true` when objective deviation is
less than `atol`.
"""
struct DefaultSADone <: AbstractSADone
    atol::Float64
end

################################################################################
# Placement Routine!
################################################################################

function place(
        sa::SAStruct;
        move_attempts = 50_000,
        # Parameters for high-level control
        warmer ::AbstractSAWarm  = DefaultSAWarm(0.9, 2.0, 0.95),
        cooler ::AbstractSACool  = DefaultSACool(0.997),
        doner  ::AbstractSADone  = DefaultSADone(10.0^-5),
        limiter::AbstractSALimit = DefaultSALimit(0.44),
       )

    # Unpack SA
    A = architecture(sa)
    D = dimension(sa)
    num_nodes = length(sa.nodes)
    num_edges = length(sa.edges)

    # Get the largest address
    max_addresses = ind2sub(sa.component_table, endof(sa.component_table))
    largest_address = maximum(max_addresses)

    # Initialize structure to help during placement.
    cost = map_cost(A, sa)
    undo_cookie = MoveCookie{typeof(cost),D}()

    # Main Simulated Annealing Loop
    loop = true

    # Start timer here - useful for printing debug information.
    # Initialize tempearture and warming up boolean variable.
    state = SAState(1.0, Float64(largest_address), cost)
    show_stats(state, true)
    while loop
        # Invert temperature to perform floating point multiplication rather
        # than division. Set local counters for this iteration.
        one_over_T = 1 / state.temperature
        accepted_moves      = 0
        successful_moves    = 0
        objective           = state.objective
        distance_limit      = max(round(Int64, state.distance_limit), 1)
        sum_cost_difference = zero(typeof(cost))
        # Inner Loop
        for i in 1:move_attempts
            # Try to generate a move. If it failed, try again.
            generate_move(A, sa, undo_cookie, distance_limit, max_addresses) || continue
            successful_moves += 1
            # Get the cost of the move
            cost_of_move = undo_cookie.cost_of_move
            if cost_of_move <= zero(typeof(cost_of_move)) ||
                    rand() < exp(-cost_of_move * one_over_T)
               accepted_moves += 1
               sum_cost_difference += abs(cost_of_move)
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
        state.recent_deviation          = sum_cost_difference / accepted_moves

        # Adjust temperature
        state.warming ? warm(warmer, state) : cool(cooler, state)
        # Adjust distance limit
        limit(limiter, state)
        # State updates
        update!(state)
        # Exit Condition
        loop = !done(doner, state)
    end
    return state
end

################################################################################
# Default state-changing functions
################################################################################
@inline function warm(w::DefaultSAWarm, state::SAState)
    # Compute acceprance ratio from the state
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_successful_moves

    # Update temperature
    state.temperature *= w.multiplier
    # Check if acceptance ratio has achieved the desired ratio
    if acceptance_ratio > w.ratio
        state.warming = false
    else
        # Decay acceptance ratio
        w.ratio *= w.decay
    end
    return nothing
end

@inline cool(c::DefaultSACool, state::SAState) = (state.temperature *= c.alpha)

@inline function done(d::DefaultSADone, state::SAState) 
    return state.deviation < d.atol
end

function limit(l::DefaultSALimit, state::SAState)
    # Compute acceptance ratio from state
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_successful_moves
    # Update distance limit
    temporary = (1 - l.ratio + acceptance_ratio)
    state.distance_limit = clamp(state.distance_limit * temporary, 1,
                                state.max_distance_limit)
    return nothing
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
        swap(sa, 
             undo_cookie.index_of_moved_node, 
             undo_cookie.index_of_other_node)
    else
        move(sa, 
             undo_cookie.index_of_moved_node,
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
                       max_addresses) where {A <: AbstractArchitecture}
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
    new_address = rand(sa.special_addresstables[-class])
    return new_address
end

