"""
Default implementation of [`RoutingChannel`](@ref).
"""
struct BasicChannel <: RoutingChannel
    """
    Direct storage for the [`Vector{PortVertices}`](@ref PortVertices) of the 
    sets of start vertices for each source of the channel.
    """
    start_vertices :: Vector{PortVertices}

    """
    Direct storage for the [`Vector{PortVertices}`](@ref PortVertices) of the 
    sets of stop vertices for each source of the channel.
    """
    stop_vertices ::Vector{PortVertices}
end

"""
    routing_channel(ruleset::RuleSet, start, stop, edge::TaskgraphEdge)

Return `<:RoutingChannel` for `edge`. Arguments `start` and `stop` are return
elements for `start_vertices` and `stop_vertices` respectively.
"""
function routing_channel(::RuleSet, start, stop, edge)
    BasicChannel(start, stop)
end

start_vertices(channel::RoutingChannel) = channel.start_vertices
stop_vertices(channel::RoutingChannel) = channel.stop_vertices

"""
    isless(a::RoutingChannel, b::RoutingChannel) :: Bool

Return `true` if `a` should be routed before `b`.
"""
Base.isless(::RoutingChannel, ::RoutingChannel) = false
