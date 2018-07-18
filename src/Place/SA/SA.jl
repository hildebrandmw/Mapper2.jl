module SA

const is07 = VERSION > v"0.7.0-"

using ..Mapper2.Helper
Helper.@SetupDocStringTemplates

using ..Mapper2.MapperCore
using ..Mapper2.MapperGraphs

using DataStructures
using Formatting
using Compat
using NamedTuples

import Base: getindex
import Base: @propagate_inbounds
import ..Mapper2.MapperCore: getaddress

is07 ? (using Logging) : (using MicroLogging)

export  SAStruct, getdistance

"""
    place!(map::Map; kwargs...) :: SAState

Run simulated annealing placement directly on `map`.

Records the following metrics into `map.metadata`:

* `placement_struct_time` - Amount of time it took to build the 
    [`SAStruct`](@ref) from `map`.

* `placement_struct_bytes` - Number of bytes allocated during the construction
    of the [`SAStruct`](@ref)

* `placement_time` - Running time of placement.

* `placement_bytes` - Number of bytes allocated during placement.

* `placement_objective` - Final objective value of placement.

Keyword Arguments
-----------------
* `seed` - Seed to provide the random number generator. Specify this to a 
    constant value for consistent results from run to run.

    Default: `rand(UInt64)`

* `move_attempts :: Integer` - Number of successful moves to generate between
    state updates. State updates include adjusting temperature, move distance
    limit, state displaying etc.

    Higher numbers will generally yield higher quality placement but with a
    longer running time.

    Default: `20000`

* `initial_temperature :: Float64` - Initial temperature that the system begins
    its warming process at. Due to the warming procedure, this should not have
    much of an affect on placement.

    Default: `1.0`.

* `supplied_state :: Union{SAState,Nothing}` - State type to use for this 
    placement. Can be used to resume placement where it left off from a previous
    run. If `nothing`, a new `SAState` object will be initialized.

    Default: `nothing`

* `movegen :: MoveGenerator` - The [`MoveGenerator`](@ref) to use for this 
    placement.

    Default: [`CachedMoveGenerator`](@ref)

* `warmer` - The [`SAWarm`](@ref) warming schedule to use.

    Default: [`DefaultSAWarm`](@ref)

* `cooler` - The [`SACool`](@ref) cooling schedule to use.

    Default: [`DefaultSACool`](@ref)

* `limiter` - The [`SALimit`](@ref) move distance limiting algorithm to 
    use.

    Default: [`DefaultSALimit`](@ref)

* `doner` - The [`SADone`](@ref) exit condition to use.

    Default: [`DefaultSADone`](@ref)
"""
function place!(m::Map{<:Architecture}; seed = rand(UInt64), kwargs...)
    # Configure random seed.
    @info "Using Seed: $seed"
    srand(seed)
    # Record how long it takes to build the placement struct and the number
    # of bytes allocated to do so.
    sastruct, struct_time, struct_bytes, _, _ = @timed SAStruct(m; kwargs...)
    # Record how long it takes for placement - after creation of the SAStruct.
    sastate, place_time, place_bytes, _, _ = @timed place!(sastruct; kwargs...)
    record(m, sastruct)

    # Record the mapping time in the map metadata.
    m.metadata["placement_struct_time"]     = struct_time
    m.metadata["placement_struct_bytes"]    = struct_bytes
    m.metadata["placement_time"]            = place_time
    m.metadata["placement_bytes"]           = place_bytes
    m.metadata["placement_objective"]       = map_cost(sastruct)

    return m
end

include("MapTables.jl")
include("Distance.jl")
include("Struct.jl")
include("Methods.jl")
include("InitialPlacement.jl")
include("State.jl")
include("MoveGenerators.jl")
include("Algorithm.jl")

end #module SA
