# Default link for recording the information about routing links.
"""
Default implementation of [`RoutingLink`](@ref)

Simple container for channel indices, cost, and capacity.

Constructors
------------
$(METHODLIST)
"""
struct BasicRoutingLink <: RoutingLink
    "Vector of channels curently assigned to the link."
    channels :: Vector{ChannelIndex}

    "Base cost of using this link."
    cost :: Float64

    """
    Number of channels that can be mapped to this link without it being 
    considered congested.
    """
    capacity :: Int64
end
BasicRoutingLink(;cost = 1.0, capacity = 1) = BasicRoutingLink(ChannelIndex[], cost, capacity)

# API Methods
@inline channels(a::RoutingLink)   = a.channels
@inline cost(a::RoutingLink)       = a.cost
@inline capacity(a::RoutingLink)   = a.capacity
@inline occupancy(a::RoutingLink)  = length(a.channels)

addchannel(a::RoutingLink, c) = push!(channels(a),c)

function remchannel(a::RoutingLink, c) 
    deleteat!(a.channels,findfirst(x -> x == c, a.channels))
end

# Derived Methods
iscongested(a::RoutingLink) = occupancy(a) > capacity(a)
iscongested(links::Vector{<:RoutingLink}) = any(iscongested, links)

################################################################################
# Routing Link Documentation
################################################################################


@doc """
    channels(link::RoutingLink) :: Vector{ChannelIndex}

Return list of channels currently occupying `link`.
""" channels

@doc """
    cost(link::RoutingLink) :: Float64

Return the base cost of a channel using `link` as a routing resource.
""" cost

@doc """
    capacity(link::RoutingLink) :: Real

Return the capacity of `link`.
""" capacity

@doc """
    occupancy(link::RoutingLink)

Return the number of channels currently using `link`.
""" occupancy

@doc """
    addchannel(link::RoutingLink, channel::ChannelIndex)

Record that `channel` is using `link`.
""" addchannel

@doc """
    remchannel(link::RoutingLink, channel::ChannelIndex)

Remove `channel` from the list of channels using `link`.
""" remchannel
