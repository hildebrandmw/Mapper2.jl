# Default link for recording the information about routing links.
struct RoutingLink <: AbstractRoutingLink
    channels::Vector{Int64}
    cost    ::Float64
    capacity::Int64
end

RoutingLink(;cost = 1.0, capacity = 1) = RoutingLink(Int[], cost, capacity)

# Accessor functions
@inline channels(a::AbstractRoutingLink)   = a.channels
@inline cost(a::AbstractRoutingLink)       = a.cost
@inline capacity(a::AbstractRoutingLink)   = a.capacity
@inline occupancy(a::AbstractRoutingLink)  = length(a.channels)

# Methods
iscongested(a::AbstractRoutingLink) = occupancy(a) > capacity(a)
addchannel(a::AbstractRoutingLink, c) = push!(channels(a),c)

function remchannel(a::AbstractRoutingLink, c) 
    deleteat!(a.channels,findfirst(x -> x == c, a.channels))
end

function iscongested(a::Vector{L}) where L <: AbstractRoutingLink
    for link in a
        iscongested(link) && return true
    end
    return false
end
################################################################################
# Routing Link Documentation
################################################################################

@doc """
Default [`AbstractRoutingLink`](@ref) implementing only the required interface.

# Constructor
    RoutingLink(;cost = 1.0, capacity = 1)
""" RoutingLink

@doc """
    channels(l::AbstractRoutingLink)

Return list of channels currently occupying `l`.
""" channels

@doc """
    cost(l::AbstractRoutingLink)

Return the cost of `l`.
""" cost

@doc """
    capacity(l::AbstractRoutingLink)

Return the capacity of `l`.
""" capacity

@doc """
    occupancy(l::AbstractRoutingLink)

Return the current occupancy of `l`.
""" occupancy

@doc """
    iscongested(l::AbstractRoutingLink)

Return `true` if `occupancy(l) > capacity(l)`

    iscongested(v::Vector{L}) where {L <: AbstractRoutingLink}

Return `true` if at least one element of `v` is congested.
""" iscongested

@doc """
    addchannel(l::AbstractRoutingLink, c::Int64)

Add `c` to the channels in `l`.
""" addchannel

@doc """
    remchannel(l::AbstractRoutingLink, c::Int64)

Remove `c` from the channels in `l`.
""" remchannel
