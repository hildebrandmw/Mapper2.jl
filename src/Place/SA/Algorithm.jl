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

# constructor for non-flat architectures
function MoveCookie(::SAStruct{A,U,D,D1}) where {A,U,D,D1} 
    MoveCookie(0.0, 0, false, 0, Location{D}())
end

# constructor for flat architecture - check if the grid is the same dimension
# as the dimensionality of the architecture
function MoveCookie(::SAStruct{A,U,D,D}) where {A,U,D}
    MoveCookie(0.0, 0, false, 0, zero(CartesianIndex{D}))
end


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
Default distance limit updater. Will adjust the distance limit so approximate
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
        sa::SAStruct{A,U,D};
        # Number of moves before doing a parameter update.
        move_attempts       = 50_000,
        move_gen            = SubRandomGenerator{D}(),
        initial_temperature = 1.0,
        supplied_state      = nothing,
        # Parameters for high-level control
        warmer ::AbstractSAWarm  = DefaultSAWarm(0.96, 2.0, 0.97),
        cooler ::AbstractSACool  = DefaultSACool(0.997),
        doner  ::AbstractSADone  = DefaultSADone(10.0^-5),
        limiter::AbstractSALimit = DefaultSALimit(0.44),
        kwargs...
       ) where {A,U,D}

    @info "Running Simulated Annealing Placement."

    # Unpack SA
    num_nodes = length(sa.nodes)
    num_edges = length(sa.edges)

    # Get the largest address
    @compat max_addresses = last((CartesianIndices(sa.component_table))).I
    largest_address = maximum(max_addresses)

    # Initialize structure to help during placement.
    cost = map_cost(A, sa)
    cookie = MoveCookie(sa)

    # Main Simulated Annealing Loop
    loop = true

    # Initialize the main state variable. State variable's timer begins when
    # the structure is created.
    if supplied_state == nothing
        state = SAState(initial_temperature, Float64(largest_address), cost)
    else
        state = supplied_state
        reset!(state)
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
            if !generate_move(sa, cookie, move_gen, distance_limit, max_addresses)
                continue
            end

            successful_moves += 1
            # Get the cost of the move
            cost_of_move = cookie.cost_of_move
            if cost_of_move <= zero(typeof(cost_of_move)) ||
                    rand() < exp(-cost_of_move * one_over_T)
               accepted_moves += 1
               sum_cost_difference += abs(cost_of_move)
               objective += cost_of_move
            else
               undo_move(sa, cookie)
            end
        end

        ###########################
        # Post iteration routines #
        ###########################
        # Update cost for numerical stability reasons
        state.objective = map_cost(A, sa)
        # Sanity Check
        if objective != state.objective
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
    temporary = (1 - l.ratio + acceptance_ratio)
    state.distance_limit = clamp(state.distance_limit * temporary, 1,
                                state.max_distance_limit)
    return nothing
end

################################################################################
# Movement related functions
################################################################################
function move_with_undo(sa::SAStruct{A}, cookie, index::Int64, new_location) where A
    node = sa.nodes[index]
    # Store the old information
    old_location = location(node)
    cookie.index_of_moved_node = index
    cookie.old_location = old_location
    # Check to see if there is a node already mapped to this location
    occupying_node = sa.grid[new_location]
    if occupying_node == 0
        cookie.move_was_swap = false

        base_cost = node_cost(A, sa, index)
        move(sa, index, new_location)
        moved_cost = node_cost(A, sa, index)

        cookie.cost_of_move = moved_cost - base_cost
    else
        # Check if the node at the new location can be moved to the old location
        isvalid(sa.maptable, occupying_node, old_location) || return false
        cookie.move_was_swap = true
        # Save the index of the occupying node
        cookie.index_of_other_node  = occupying_node
        # Compute the cost before the move
        base_cost = node_pair_cost(A, sa, index, occupying_node)
        # Swap nodes
        swap(sa, index, occupying_node)
        # Get cost after move and store
        #moved_cost = node_cost(A, sa, node) + node_cost(A, sa, occupying_node)
        moved_cost = node_pair_cost(A, sa, index, occupying_node)
        cookie.cost_of_move = moved_cost - base_cost
    end
    return true
end

"""
    undo_move(sa::SAStruct, cookie)

Undo the last move made to the `sa` with the help of the `cookie`.
"""
function undo_move(sa::SAStruct, cookie)
    # If the last move was a swap, need a swap in order to undo it.
    if cookie.move_was_swap
        swap(sa, cookie.index_of_moved_node, cookie.index_of_other_node)
    # Otherwise, a simple move is just fine.
    else
        move(sa, cookie.index_of_moved_node, cookie.old_location)
    end
    return nothing
end
################################################################################
# DEFAULT MOVE GENERATION
################################################################################
canmove(::Type{A}, x) where {A <: AbstractArchitecture} = true

# Move generation in the general case.
function generate_move(sa::SAStruct{A}, 
                       cookie, 
                       move_gen::AbstractMoveGenerator,
                       limit, 
                       upperbound) where {A <: AbstractArchitecture} 
    # Pick a random node
    index = getlinear(move_gen, length(sa.nodes))
    canmove(A, sa.nodes[index]) || return false

    old_address = getaddress(sa.nodes[index])
    maptable = sa.maptable
    # Get the equivalent class of the node
    class = maptable.class[index]
    # Get the address and component to move this node to
    if isnormal(class)
        # Generate offset and check bounds.
        address = old_address + getoffset(move_gen, limit)
        boundscheck(address, upperbound) || return false
        # Now that we know our location is inbounds, find a component for it
        # to live in.
        components = maptable.normal_lut[class][address]
        lc = length(components)
        lc == 0 && return false
        component = components[getlinear(move_gen, lc)]
        new_location = Location(address, component)
    else
        new_location = rand(maptable.special_lut[-class])
    end
    # Perform the move and record enough information to undo the move. The
    # function "move_with_undo" will return false if the move is a swap and
    # the moved node cannot be placed.
    return move_with_undo(sa::SAStruct, cookie, index, new_location)
end

function boundscheck(addr::CartesianIndex{N}, ub) where N
    for i in 1:N
        if !(1 <= addr.I[i] <= ub[i])
            return false
        end
    end
    return true
end


function generate_move(sa::SAStruct{A,U,D,D}, 
                       cookie::MoveCookie, 
                       move_gen::AbstractMoveGenerator, 
                       limit, upperbound) where {A <: AbstractArchitecture, U,D}

    #index = rand(1:length(sa.nodes))
    index = getlinear(move_gen, length(sa.nodes))
    canmove(A, sa.nodes[index]) || return false

    old_address = getaddress(sa.nodes[index])
    maptable    = sa.maptable
    class       = maptable.class[index]
    if isnormal(class)
        address = old_address + getoffset(move_gen, limit)
        # Check if in-bounds.
        boundscheck(address, upperbound) || return false
        # Check if this is an acceptable destination address
        maptable.normal_lut[class][address] || return false
    else
        address = rand(maptable.special_lut[-class])
    end
    return move_with_undo(sa::SAStruct, cookie, index, address)
end
