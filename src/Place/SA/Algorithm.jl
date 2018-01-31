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

struct TrueSAWarm <: AbstractSAWarm end

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
        supplied_state = nothing,
        # Number of moves before doing a parameter update.
        move_attempts = 20_000,
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

    # TODO: Make plotting options more seamless.
    if USEPLOTS
        # Use the last worker as the worker that will generate all of the
        # plots.
        plot_proc = workers()[end]
        plot_channel = Channel{Any}(1)
        @async put!(plot_channel, remotecall_fetch(plot, plot_proc, deepcopy(sa)))
    end

    # Initialize the main state variable. State variable's timer begins when
    # the structure is created.
    if supplied_state == nothing
        state = SAState(1.0, Float64(largest_address), cost)
    else
        state = supplied_state
    end

    # Print out the header for the statistic columns.
    show_stats(state, true)
    first_display = true
    while loop
        ################## 
        # Pre-loop setup #
        ################## 

        # Invert temperature to perform floating point multiplication rather
        # than division. Set local counters for this iteration.
        one_over_T = 1 / state.temperature
        accepted_moves      = 0
        successful_moves    = 0
        objective           = state.objective
        distance_limit      = max(round(Int64, state.distance_limit), 1)
        sum_cost_difference = zero(typeof(cost))

        ############## 
        # Inner Loop #
        ############## 
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
        #update!(state)
        if update!(state) && USEPLOTS
            if isready(plot_channel)
                take!(plot_channel)
                @async put!(plot_channel, remotecall_fetch(plot, 
                                                           plot_proc,
                                                           sa))
            end
        end
        # Exit Condition
        loop = !done(doner, state)
    end
    # Show final statistics
    show_stats(state)
    return state
end

################################################################################
# Default state-changing functions
################################################################################
@inline function warm(w::DefaultSAWarm, state::SAState)
    # Compute acceptance ratio from the state
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

warm(w::TrueSAWarm, state::SAState) = true

@inline cool(c::DefaultSACool, state::SAState) = (state.temperature *= c.alpha)

@inline function done(d::DefaultSADone, state::SAState) 
    return state.deviation < d.atol
end

function limit(l::DefaultSALimit, state::SAState)
    # Compute acceptance ratio from state
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_successful_moves
    # Update distance limit
    temporary = (2 - l.ratio + acceptance_ratio)
    state.distance_limit = clamp(state.distance_limit * temporary, 1,
                                state.max_distance_limit)
    return nothing
end

################################################################################
# Movement related functions
################################################################################
function isvalid(sa::SAStruct, node::Int64, address::Address, component)
    # Get the class associated with this node.
    class = sa.nodeclass[node]
    # Get the map tables for the node. Check if the component is in the 
    # maptable.
    maptable = class > 0 ? sa.maptables[class] : sa.special_maptables[-class]
    return component in maptable[address]
end

function move_with_undo(sa::SAStruct, undo_cookie, node::Int64, address, component)
    A = architecture(sa)
    # Store the old information
    old_address     = sa.nodes[node].address
    old_component   = sa.nodes[node].component
    undo_cookie.index_of_moved_node = node
    undo_cookie.old_address     = old_address
    undo_cookie.old_component   = old_component
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
        # If we can't move the node back, abort this move
        isvalid(sa, occupying_node, old_address, old_component) || return false
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
    return true
end

"""
    undo_move(sa::SAStruct, undo_cookie)

Undo the last move made to the `sa` with the help of the `undo_cookie`.
"""
function undo_move(sa::SAStruct, undo_cookie)
    # If the last move was a swap, need a swap in order to undo it.
    if undo_cookie.move_was_swap
        swap(sa, 
             undo_cookie.index_of_moved_node, 
             undo_cookie.index_of_other_node)
    # Otherwise, a simple move is just fine.
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
    # Perform the move and record enough information to undo the move. The
    # function "move_with_undo" will return false if the move is a swap and
    # the moved node cannot be placed.
    return move_with_undo(sa::SAStruct, undo_cookie, node, address, component)
end

function standard_move(::Type{A}, sa::SAStruct, address, class, limit, ub) where {
                                                      A <: AbstractArchitecture}
    # Generate a new address based on the distance limit
    move_ub = min.(address.addr .+ limit, ub)
    move_lb = max.(address.addr .- limit, 1)
    new_address = rand_address(move_lb, move_ub)
    return new_address
end

function special_move(::Type{A}, sa::SAStruct, class) where {A <: AbstractArchitecture}
    # Get the special address table for this class.
    new_address = rand(sa.special_addresstables[-class])
    return new_address
end

