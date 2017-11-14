#=
Collection of placement algorithms.
=#

# Simulated Annealing Placement - Default option.
include("SA/SA.jl")

function place(m::Map{A,D}; kwargs...) where {A <: AbstractArchitecture, D}
    placement_struct = get_placement_struct(m)
    place(placement_struct; kwargs...)
    record(m, placement_struct)
    return m
end

get_placement_struct(m::Map{A,D}) where {A <: AbstractArchitecture, D} = SAStruct(m)
