module SA

const is07 = VERSION > v"0.7.0-"

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using ..Mapper2.Place

using LightGraphs
using DataStructures
using Formatting
using Compat
using StaticArrays
using Primes

is07 ? (using Logging) : (using MicroLogging)

export  SAStruct,
        getaddress,
        getcomponent


function place(m::Map{A}; kwargs...) where {A <: AbstractArchitecture}
    # Record how long it takes to build the placement struct and the number
    # of bytes allocated to do so.
    sastruct, struct_time, struct_bytes, _, _ = @timed SAStruct(m; kwargs...)
    # Record how long it takes for placement - after creation of the SAStruct.
    sastate, place_time, place_bytes, _, _ = @timed place(sastruct; kwargs...)
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
include("Struct.jl")
include("Methods.jl")
include("InitialPlacement.jl")
include("State.jl")
include("MoveGenerators.jl")
include("Algorithm.jl")

end #module SA
