module SA

const is07 = VERSION > v"0.7.0-"

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using ..Mapper2.Place

using LightGraphs
using DataStructures
using Formatting
using Compat

is07 ? (using Logging) : (using MicroLogging)

export  SAStruct,
        getaddress,
        getcomponent


function place(m::Map{A}; kwargs...) where {A <: AbstractArchitecture}
    s = SAStruct(m; kwargs...)
    place(s; kwargs...)
    record(m, s)
    return m
end

include("Struct.jl")
include("Methods.jl")
include("InitialPlacement.jl")
include("State.jl")
include("Algorithm.jl")

end #module SA
