module SA

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using ..Mapper2.Place

using LightGraphs
using DataStructures
using Formatting
using MicroLogging

export  SAStruct


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
