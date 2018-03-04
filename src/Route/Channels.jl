const ARC = AbstractRoutingChannel

struct RoutingChannel <: ARC
    start::Vector{Vector{Int64}}
    stop ::Vector{Vector{Int64}}
end

function routing_channel(::Type{A}, start, stop, edge) where {A<:AbstractArchitecture}
    RoutingChannel(start, stop)
end

Base.start(r::ARC)   = r.start
stop(r::ARC)         = r.stop

# Fallback for choosing links to give priority to during routing.
Base.isless(::ARC, ::ARC) = false

################################################################################
# Documentation
################################################################################
@doc """
Default implementation of [`AbstractRoutingChannel`](@ref) containing only the
required fields.
""" RoutingChannel

@doc """
    routing_channel(::Type{<:AbstractArchitecture}, start, stop, edge::TaskgraphEdge)

Return some `c <: AbstractRoutingChannel` for `edge`. Start and stop nodes are
given as the required `Vector{Vector{Int64}}`.

Default: [`RoutingChannel`](@ref)

See also: [`AbstractRoutingChannel`](@ref)
""" routing_channel

@doc """
    start(c::AbstractRoutingChannel)

Return the `start` vector for `c`.
""" start

@doc """
    stop(c::AbstractRoutingChannel)

Return the `stop` vector for `c`.
""" stop

@doc """
    isless(a::ARC, b::ARC)

Return `true` if channel `a` is "less important" than `b`. Otherwise return `false`.
Used to tell routing schedule which links are more important.
""" isless
