#=
Collection of placement algorithms.
=#

module Place

using ..Mapper2: Addresses, Helper, Architecture, Taskgraphs, MapType, Debug

# Use Progress Meter for displaying information about construction of
# placement types.
using ProgressMeter
# Used for initial placement bipartite matching.
using LightGraphs
using DataStructures
using Formatting

const USEPLOTS = false

export  place,
        SAStruct,
        AbstractSANode,
        AbstractSAEdge,
        AbstractAddressData,
        BasicSANode,
        BasicSAEdge,
        ismappable,
        isspecial,
        isequivalent,
        canmap,
        get_placement_struct


# Simulated Annealing Placement - Default option.
include("SA/SA.jl")

"""
    place(m::Map{A,D}; kwargs...)

Run placement on `m` using the algorithm specified by the `placement_algorithm`
for `m`. Any keyword arguments for the placement algorithm can be passed via
`kwargs`.

Return a `Map` with the placement recorded.
"""
function place(m::Map{A,D}; kwargs...) where {A <: AbstractArchitecture, D}
    placement_struct = placement_algorithm(m)
    place(placement_struct; kwargs...)
    record(m, placement_struct)
    return m
end

# Default insertion methods
ismappable(::Type{T}, c::Component) where {T <: AbstractArchitecture} = true
isspecial(::Type{T}, t::TaskgraphNode) where {T <: AbstractArchitecture} = false
isequivalent(::Type{T}, 
             a::TaskgraphNode, 
             b::TaskgraphNode) where {T <: AbstractArchitecture} = true
canmap(::Type{T}, 
       t::TaskgraphNode, 
       c::Component) where {T <: AbstractArchitecture} = true

placement_algorithm(m::Map{A,D}) where {A <: AbstractArchitecture, D} = SAStruct(m)

end # module Place
