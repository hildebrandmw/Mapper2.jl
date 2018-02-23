module SA

using ..Mapper2.Helper
using ..Mapper2.MapperCore
using ..Mapper2.Place

# Use Progress Meter for displaying information about construction of
# placement types.
using ProgressMeter
# Used for initial placement bipartite matching.
using LightGraphs
using DataStructures
using Formatting
using MicroLogging

export  SAStruct


function place(m::Map{A}; kwargs...) where {A <: AbstractArchitecture}
    s = SAStruct(m) 
    place(s; kwargs...)
    record(m, s)
    return m
end

# Structure used for placement.
include("Struct.jl")
# Methods for interacting with that structure
include("Methods.jl")
# Initial Placement Routine
include("InitialPlacement.jl")
# State variable for placement
include("State.jl")
# The actual simulated annealing algorithm
include("Algorithm.jl")

end #module SA
