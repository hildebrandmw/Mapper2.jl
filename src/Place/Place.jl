module Place

using ..Mapper2.MapperCore

export  place,
        ismappable,
        isspecial,
        isequivalent,
        canmap,
        placement_routine

const AA = AbstractArchitecture
const TN = TaskgraphNode

"""
    place(m::Map{A,D}; kwargs...)

Run placement on `m` using the algorithm specified by the `placement_algorithm`
for `m`. Any keyword arguments for the placement algorithm can be passed via
`kwargs`.

Return a `Map` with the placement recorded.
"""
function place(m::Map{A,D}; kwargs...) where {A <: AA, D}
    f = placement_routine(A)
    return f(m, kwargs...)
end

# Default insertion methods
ismappable(::Type{T}, c::Component) where {T <: AA} = true
isspecial(::Type{T}, t::TN) where {T <: AA} = false
isequivalent(::Type{T}, a::TN, b::TN) where {T <: AA} = true
canmap(::Type{T}, t::TN, c::Component) where {T <: AA} = true 

# Placeholder
placement_routine() = nothing

end # module Place
