#=
Collection of placement algorithms.
=#

# Simulated Annealing Placement - Default option.
include("SA/SA.jl")

function place(m::Map{A,D}) where {A <: AbstractArchitecture, D}
    placement_struct = get_placement_struct(m)
    place(placement_struct)
    return placement_struct
end

get_placement_struct(m::Map{A,D}) where {A <: AbstractArchitecture, D} = SAStruct(m)
