module Place

using ..Mapper2.MapperCore
using MicroLogging

export  place,
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
function place(m::Map{A}; seed = rand(UInt64), kwargs...) where {A <: AA}
    @info "Using Seed: $seed"
    srand(seed)
    f = placement_routine(A)
    return f(m; kwargs...)
end


# Placeholder
placement_routine() = nothing

end # module Place
