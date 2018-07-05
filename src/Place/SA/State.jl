################################################################################
# Structure to keep track of performance information
################################################################################
mutable struct SAState
    #= Information related to most recent move attempt =#
    "Current Temperature of the system"
    temperature         ::Float64
    "Current objective value"
    objective           ::Float64
    "Current Distance Limit"
    distance_limit      ::Float64
    distance_limit_int  ::Int64
    max_distance_limit  ::Float64

    "Current number of move attempts"
    recent_move_attempts    ::Int64
    recent_successful_moves ::Int64
    recent_accepted_moves   ::Int64
    recent_deviation        ::Float64

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
    "Average Deviaation"
    deviation::Float64
    "Creation time of the structure"
    start_time::Float64
    "Running Time - only an approximate measure"
    run_time::Float64
    #= Methods for dealing with the updates =#
    display_updates::Bool
    "Time of the last update"
    last_update_time::Float64
    "Update Interval"
    dt::Float64

    #= Auxiliary cost =#
    aux_cost::Float64

    function SAState(temperature, distance_limit, objective)
        # This is a hack to "cleanly" determine if we should display updates
        # or not.
        display_updates = true
        # if MicroLogging.Info >= MicroLogging._min_enabled_level[]
        #     display_updates = true
        # end

        SAStateUpdateInterval = 5
        return new(
            # Most recent run
            temperature,        # temperature
            Float64(objective), # objective
            distance_limit,     # distance_limit
            floor(Int,distance_limit), # distance_limit_int
            distance_limit,     # max_distance_limit (set to initial)
            0,                  # recent_move_attempts
            0,                  # recent_successful_moves
            0,                  # recent_accepted_moves
            0.0,                # recent_deviation
            true,               # warming

            # Global run
            0,      # total_moves
            0,      # suffessful_moves
            0,      # accepted_moves
            0.0,    # moves_per_second
            0.0,    # deviation
            time(), # creation time
            time(), # runtime

            # Update parameters
            display_updates,
            time(),                     # Time of creation
            SAStateUpdateInterval,      # Default update interval

            # auxiliary cost
            0.0
         )
    end
end

function reset!(s::SAState)
    s.recent_move_attempts     = 0
    s.recent_successful_moves  = 0
    s.recent_accepted_moves    = 0
    s.recent_deviation         = 0.0

    s.warming = true
end

function update!(state::SAState)
    # Update the global counters
    state.total_moves       += state.recent_move_attempts
    state.successful_moves  += state.recent_successful_moves
    state.accepted_moves    += state.recent_accepted_moves
    # Compute number of moves per second.
    state.moves_per_second = state.successful_moves / (time() - state.start_time)
    # Update the exponential moving average of the objective function differnce.
    alpha = 0.2
    state.deviation = alpha * state.recent_deviation +
                        (1.0 - alpha) * state.deviation
    # Determine whether or not to print out results
    current_time = time()
    state.run_time = current_time - state.start_time
    if current_time > state.last_update_time + state.dt
        show_stats(state)
        state.last_update_time = time()
    end

    # Compute the new distance limit integer and return "true" if it changed.
    new_distance_limit_int = max(1, round(Int, state.distance_limit))

    return_value = false
    if new_distance_limit_int != state.distance_limit_int
        return_value = true
    end
    state.distance_limit_int = new_distance_limit_int
    return return_value
end

#=
TODO: If this turns out to be really useful, think about writing a kernel
function to generalize this to other state objects.
=#
"""
    show_stats(state::SAState, first = false)

Print out stats about the SAState object in columns. If `first = true`, will
print a header outlining the contents of eath column.
"""
function show_stats(state::SAState, first = false)
     state.display_updates || return nothing
     #=
     Fields of the SAState will be printed to the console in the order the
     order they show up here.

     The field name will be printed at the beginning of an placement iteration.
     Under-scores will be removed and the first letter of each word will
     be capitalized.

     The space occupied by the field name and the subsequent printed values
     will scale depending on the length of the string conversion of the
     field name. Thus, if the fields are printed out in a different order,
     everything should still look good.
     =#
     fields = (
        :temperature,
        :objective,
        :total_moves,
        :successful_moves,
        :accepted_moves,
        :moves_per_second,
        #:deviation,
        :run_time,
        :distance_limit,
        :aux_cost,
    )

    #=
    Key-word arguments for the "format" function. Add to this to fine tune
    how the result will be printed. Don't include the :width keyword argument
    as that will be automatically determined based on the width needed to
    print the field name.

    The "format" function belongs to the "Formatting" package.
    =#
    kwargs = Dict(
        :temperature        => Dict(:precision => 5),
        :objective          => Dict(:precision => 2),
        :moves_per_second   => Dict(:precision => 3,
                                    :autoscale => :metric),
        :deviation          => Dict(:precision => 3,
                                    :autoscale => :metric),
        :run_time           => Dict(:precision => 2)
    )

    #=
    Spacing between words and fields. The white space allows easier
    differentiation for each field.
    =#
    spacing = 4

    #=
    If this is the first iteration, just print each field name and underline
    it with a bunch of "-".
    =#
    if first
        # Record the total number of characters written to the console.
        total_length = 0
        # Iterate through each field in order
        for f in fields
            # Replace the under scores in the field name with a space.
            @compat string_f = replace(string(f), "_" => " ")
            # Get the length of the string and add in the spacing between
            # strings
            padded_length = length(string_f) + spacing
            # Pad the string to the desired length and capitalize the first
            # word of each sentence.
            string_to_print = titlecase(lpad(string_f, padded_length))
            # Print to console
            @compat printstyled(string_to_print, bold = true, color = :light_green)
            # Record the number of characters written.
            total_length += padded_length
        end
        # Create a new line and print hyphens for the number of characters written.
        println("\n", "-" ^ total_length)

    #=
    Print out the numerical values for the requested fields.
    =#
    else
        # Iterate through fields in roder.
        for f in fields
            # Get the length of the field - append one space to the front.
            field_length = length(string(f)) + spacing
            # Get the format preferences dictionary
            kwarg = get(kwargs, f, Dict())
            # Check if we have to shorten the length - adjust because the "width'
            # parameter apparently doesn't take this into account
            haskey(kwarg, :autoscale) && (field_length -= 1)
            # Add the width field to the dictionary.
            kwarg[:width] = field_length
            # Print out the value of the field with the given options. Use
            # the function "format" from the "Formatting" package to make
            # things look nice.
            print(format(getfield(state,f); kwarg...))
        end
        # Terminate with a new line.
        print("\n")
    end
    return nothing
end
