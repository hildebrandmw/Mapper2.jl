#=
Simulated Annealing placement.
=#

################################################################################
# Type to keep track of previous moves.
################################################################################
abstract type AbstractCookie end
mutable struct MoveCookie{T} <: AbstractCookie
   cost_of_move            ::Float64
   index_of_moved_node     ::Int64
   move_was_swap           ::Bool
   index_of_other_node     ::Int64
   old_location            ::T
end

function MoveCookie(sa_struct :: SAStruct)
    MoveCookie(0.0, 0, false, 0, zero(eltype(sa_struct)))
end

################################################################################
# Types that control various parameters of the placement.
################################################################################


##########
# SAWarm #
##########
"""
Abstract type controlling the warming cycle of Simulated Annealing placement.

API
---
* [`warm!`](@ref)

Implementations
---------------
* [`DefaultSAWarm`](@ref)
"""
abstract type SAWarm end

#-----#
# API #
#-----#
"""
    warm!(warmer :: SAWarm, state :: SAState)

Increase `state.temperature` according to `warmer`. If `warmer` decides that
the system is done warming up, it must set `state.warming = false`.

Method List
-----------
$(METHODLIST)
"""
function warm! end

#----------------#
# Implementation #
#----------------#

"""
Default imeplementation of [`SAWarm`](@ref).

On each invocation, will multiply the temperature of
the anneal by `multiplier`. When the acceptance ratio rises above `ratio`,
warming routine will end.

To prevent unbounded warming, the `ratio` field is multiplied by the `decay`
field on each invocation.
"""
mutable struct DefaultSAWarm <: SAWarm
    ratio       ::Float64
    multiplier  ::Float64
    decay       ::Float64
end

@inline function warm!(w::DefaultSAWarm, state::SAState)
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

##########
# SACool #
##########

"""
Cooling schedule for Simulated Annealing placement.

API
---
* [`cool!`](@ref)

Implementations
---------------
* [`DefaultSACool`](@ref)

"""
abstract type SACool end

#-----#
# API #
#-----#

"""
    cool!(cooler :: SACool, state :: SAState)

When called, may decrease `state.temperature`.

Method List
-----------
$(METHODLIST)
"""
function cool! end

#----------------#
# Implementation #
#----------------#

"""
Default cooling schedule. Each invocation, will multiply the temperature
of the anneal by the `alpha` parameter.
"""
struct DefaultSACool <: SACool
    alpha::Float64
end

@inline cool!(c::DefaultSACool, state::SAState) = (state.temperature *= c.alpha)

####################
# Distance Limiter #
####################

"""
Type that controls the length contraction mechanism of Simulated Annealing
placement.

API
---
* [`limit!`](@ref)

Implmementations
----------------
* [`DefaultSALimit`](@ref)

"""
abstract type SALimit end

#-----#
# API #
#-----#
"""
    limit!(limiter :: SALimit, state :: SAState)

Mutate `state.distance_limit` when called.
"""
function limit! end

#----------------#
# Implementation #
#----------------#

"""
Default distance limit updater. Will adjust the distance limit so approximate
`ratio` of moves are accepted. Will not set `state.limit` lower than `minimum`.
"""
struct DefaultSALimit <: SALimit
    ratio :: Float64
    # Minimum allows distance limit.
    minimum :: Int
end
DefaultSALimit(ratio::Float64) = DefaultSALimit(ratio, 1)

function limit!(l::DefaultSALimit, state::SAState)
    # Compute acceptance ratio from state
    acceptance_ratio = state.recent_accepted_moves /
                       state.recent_successful_moves
    # Update distance limit
    temporary = (1 - l.ratio + acceptance_ratio)
    state.distance_limit = clamp(
        state.distance_limit * temporary,
        l.minimum,
        state.max_distance_limit
    )
    return nothing
end

##########
# SADone #
##########

"""
Control when to terminate Simulated Annealing placement.

API
---
* [`sa_done`](@ref)

Implementations
---------------
* [`DefaultSADone`]

"""
abstract type SADone end

#-----#
# API #
#-----#

"""
    sa_done(doner :: SADone, state :: SAState)

Return `true` to finish placement.
"""
function sa_done end

#---------------#
# Implmentation #
#---------------#

"""
Default end detection. Will return `true` when objective deviation is
less than `atol`.
"""
struct DefaultSADone <: SADone
    atol :: Float64
end

@inline function sa_done(d::DefaultSADone, state::SAState)
    return !state.warming && (state.deviation < d.atol)
end

################################################################################
# Placement Routine!
################################################################################

function place!(
        sa_struct :: SAStruct{A,U,D};
        # Number of moves before doing a parameter update.
        move_attempts       = 20000,
        initial_temperature = 1.0,
        supplied_state      = nothing,
        movegen :: MoveGenerator = CachedMoveGenerator(sa_struct),
        # Parameters for high-level control
        warmer :: SAWarm  = DefaultSAWarm(0.96, 2.0, 0.97),
        cooler :: SACool  = DefaultSACool(0.999),
        doner :: SADone  = DefaultSADone(10.0^-5),
        limiter :: SALimit = DefaultSALimit(0.44, 2),
        kwargs...
    ) where {A,U,D}

    @info "Running Simulated Annealing Placement."
    # Set the random number generator for repeatable results.

    # Unpack SA
    num_nodes = length(sa_struct.nodes)
    num_channels = length(sa_struct.channels)

    # Get the largest address
    max_addresses = size(sa_struct.pathtable)
    largest_address = maximum(max_addresses)

    initial_move_limit = distancelimit(movegen, sa_struct)

    # Initialize structure to help during placement.
    cost = map_cost(sa_struct)
    cookie = MoveCookie(sa_struct)

    # Main Simulated Annealing Loop
    loop = true

    # Initialize the main state variable. State variable's timer begins when
    # the structure is created.
    if supplied_state == nothing
        state = SAState(initial_temperature, Float64(initial_move_limit), cost)
    else
        state = supplied_state
        reset!(state)
    end

    # Initialize move generator
    initialize!(movegen, sa_struct, state.distance_limit)

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
        sum_cost_difference = zero(typeof(cost))

        ##############
        # Inner Loop #
        ##############
        while successful_moves < move_attempts
            # Try to generate a move. If it failed, try again.
            @inbounds success = generate_move!(sa_struct, movegen, cookie)
            if !success
                continue
            end

            successful_moves += 1
            # Get the cost of the move
            cost_of_move = cookie.cost_of_move
            if cost_of_move <= zero(typeof(cost_of_move)) ||
                    rand() < exp(-cost_of_move * one_over_T)
                accepted_moves += 1

                if cost_of_move > 0
                    sum_cost_difference += cost_of_move
                end

                objective += cost_of_move
            else
                undo_move(sa_struct, cookie)
            end
        end

        ###########################
        # Post iteration routines #
        ###########################
        # Update cost for numerical stability reasons
        state.objective = map_cost(sa_struct)
        # Sanity Check

        if !isapprox(objective, state.objective)
            @warn """
            Objective mismatch.
            actual: $(state.objective).
            calculated: $objective.
            """
        end

        # Update some statistics in the state variable
        state.recent_move_attempts      = move_attempts
        state.recent_successful_moves   = successful_moves
        state.recent_accepted_moves     = accepted_moves
        # Quick check to avoid NaN's showing up in the case of zero accepted
        # moves.
        if iszero(accepted_moves)
            state.recent_deviation = 0
        else
            state.recent_deviation = sum_cost_difference / accepted_moves
        end
        state.aux_cost = aux_cost(sa_struct)

        # Adjust temperature
        state.warming ? warm!(warmer, state) : cool!(cooler, state)
        # Adjust distance limit - only if we're not warming up.
        state.warming || limit!(limiter, state)

        # State updates - check if we potentially need to do some recomputation
        # for the move generator
        update_movegen = update!(state)

        if update_movegen
            update!(movegen, sa_struct, state.distance_limit_int)
        end

        # Exit Condition
        loop = !sa_done(doner, state)
    end
    # Show final statistics
    show_stats(state)

    return state
end

################################################################################
# Movement related functions
################################################################################
@propagate_inbounds function move_with_undo(
        sa_struct::SAStruct,
        cookie,
        index::Int64,
        new_location
    )

    node = sa_struct.nodes[index]

    # Store the old information
    old_location = location(node)
    cookie.index_of_moved_node = index
    cookie.old_location = old_location
    # Check to see if there is a node already mapped to this location
    occupying_node_index = sa_struct.grid[new_location]
    if occupying_node_index == 0
        cookie.move_was_swap = false

        base_cost = node_cost(sa_struct, index)
        move(sa_struct, index, new_location)
        moved_cost = node_cost(sa_struct, index)

        cookie.cost_of_move = moved_cost - base_cost
    else
        occupying_node = sa_struct.nodes[occupying_node_index]

        # Check if the node at the new location can be moved to the old location
        isvalid(sa_struct.maptable, getclass(occupying_node), old_location) || return false
        cookie.move_was_swap = true
        # Save the index of the occupying node
        cookie.index_of_other_node  = occupying_node_index
        # Compute the cost before the move
        base_cost = node_pair_cost(sa_struct, index, occupying_node_index)
        # Swap nodes
        swap(sa_struct, index, occupying_node_index)
        # Get cost after move and store
        moved_cost = node_pair_cost(sa_struct, index, occupying_node_index)
        cookie.cost_of_move = moved_cost - base_cost
    end
    return true
end

@propagate_inbounds function undo_move(sa_struct::SAStruct, cookie)
    # If the last move was a swap, need a swap in order to undo it.
    if cookie.move_was_swap
        swap(sa_struct, cookie.index_of_moved_node, cookie.index_of_other_node)
    # Otherwise, a simple move is just fine.
    else
        move(sa_struct, cookie.index_of_moved_node, cookie.old_location)
    end
    return nothing
end
