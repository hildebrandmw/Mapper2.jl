"""
    assign(sa::SAStruct, node, component, address)

Assigns the `node` index to the given `address` and `component` index at that
address.
"""
@propagate_inbounds function assign(sa::SAStruct, index, spot)
    node = sa.nodes[index]
    # update node then grid.
    assign(node, spot)
    sa.grid[location(node)] = index
end

"""
    move(sa::SAStruct, node, component, address)

Move `node` to the given `component` and `address`.
"""
@propagate_inbounds function move(sa::SAStruct, index, spot)
    node = sa.nodes[index]
    sa.grid[location(node)] = 0
    assign(node, spot)
    sa.grid[location(node)] = index
end

"""
    swap(sa::SAStruct, node1, node2)

Swap two nodes in the placement structure.
"""
@propagate_inbounds function swap(sa::SAStruct, node1, node2)
    # Get references to these objects to make life easier.
    n1 = sa.nodes[node1]
    n2 = sa.nodes[node2]
    # Swap address/component assignments
    s = location(n1)
    t = location(n2)

    assign(n1, t)
    assign(n2, s)
    # Swap grid.
    sa.grid[t] = node1
    sa.grid[s] = node2

    return nothing
end

################################################################################
# DEFAULT METRIC FUNCTIONS
################################################################################
#=
Right now, this first function is basically a dispatch method to handle the
case when we have multiple channel types.

Ideas include:

1. Allow type dispatch to do everything.
2. Make this a "generated" function based on all the types of the channels and
    build a "case" statement out of it.
=#
@propagate_inbounds function channel_cost(
        ::Type{A}, 
        sa::SAStruct, 
        i::Int
    ) where {A <: AbstractArchitecture}

    return channel_cost(A, sa, sa.channels[i])
end

@propagate_inbounds function channel_cost(
        ::Type{<:AbstractArchitecture},
        sa::SAStruct,
        channel::TwoChannel
    )

    a = getaddress(sa.nodes[channel.source])
    b = getaddress(sa.nodes[channel.sink])
    distance = sa.distance[a,b]

    return Float64(distance)
end

@propagate_inbounds function channel_cost(
        ::Type{<:AbstractArchitecture}, 
        sa::SAStruct, 
        channel::MultiChannel
    )

    cost = 0.0
    for src in channel.sources, snk in channel.sinks
        # Get the source and sink addresses
        a = getaddress(sa.nodes[src])
        b = getaddress(sa.nodes[snk])
        cost += sa.distance[a,b]
    end
    return cost
end

address_cost(::Type{<:AbstractArchitecture}, sa::SAStruct, node::Node) = zero(Float64)
aux_cost(::Type{<:AbstractArchitecture}, sa::SAStruct) = zero(Float64)

map_cost(sa::SAStruct{A}) where A = map_cost(A, sa)
function map_cost(::Type{A}, sa::SAStruct) where {A <: AbstractArchitecture}
    cost = aux_cost(A, sa)
    for i in eachindex(sa.channels)
        cost += channel_cost(A, sa, i)
    end
    for n in sa.nodes
        cost += address_cost(A, sa, n)
    end
    return cost
end

@propagate_inbounds function node_cost(
        ::Type{A}, 
        sa::SAStruct, 
        index::Integer
    ) where {A <: AbstractArchitecture}

    # Unpack node data type.
    n = sa.nodes[index]
    cost = aux_cost(A, sa)
    for channel in n.outchannels
        cost += channel_cost(A, sa, channel)
    end
    for channel in n.inchannels
        cost += channel_cost(A, sa, channel)
    end
    cost += address_cost(A, sa, n)

    return cost
end

#=
Node pair cost is slightly more subtle than just each independent node cost if

    1. The communication resources in the array are asymmetric. Then if two
        nodes are swapped and are connected by a channel, the double cost of
        that channel is not cancelled out correctly.

    2. For multi-pin nets, if a source and sink are swapped, then the the
        objective function is calculated incorrectly due to counting the channel
        twice.
=#
@propagate_inbounds function node_pair_cost(
        ::Type{A}, 
        sa::SAStruct, 
        i,
        j,
    ) where {A <: AbstractArchitecture}

    cost = node_cost(A, sa, i)
    # Get the two node types for calculating the cost of the second node.
    a = sa.nodes[i]
    b = sa.nodes[j]

    for channel in b.outchannels
        if !in(channel, a.inchannels)
            cost += channel_cost(A, sa, channel)
        end
    end
    for channel in b.inchannels
        if !in(channel, a.outchannels)
            cost += channel_cost(A, sa, channel)
        end
    end
    cost += address_cost(A, sa, b)
    return cost
end
