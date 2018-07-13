"""
$(SIGNATURES)

Move node at `index` to `new_location`.
"""
@propagate_inbounds function assign(sa_struct::SAStruct, index, new_location)
    node = sa_struct.nodes[index]
    # Assign this location to the new node.
    assign(node, new_location)
    # Update the grid to point to the node.
    sa_struct.grid[location(node)] = index
end

"""
$(SIGNATURES)

Move node at `index` from its current location to `new_location`.
"""
@propagate_inbounds function move(sa_struct::SAStruct, index, new_location)
    node = sa_struct.nodes[index]
    # Zero out this node's original location in the grid, then assign the new
    # location.
    sa_struct.grid[location(node)] = 0
    assign(node, new_location)
end

"""
$(SIGNATURES)

Swap the locations of two nodes with indices `node1_idx` and `node2_idx`.
"""
@propagate_inbounds function swap(sa_struct::SAStruct, node1_idx, node2_idx)
    # Get references to these objects to make life easier.
    n1 = sa_struct.nodes[node1_idx]
    n2 = sa_struct.nodes[node2_idx]
    # Swap address/component assignments
    s = location(n1)
    t = location(n2)

    assign(n1, t)
    assign(n2, s)
    # Swap grid.
    sa_struct.grid[t] = node1_idx
    sa_struct.grid[s] = node2_idx

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
        sa_struct::SAStruct, 
        idx::Int
    ) where {A <: Architecture}

    return channel_cost(A, sa_struct, sa_struct.channels[i])
end

"""
$(SIGNATURES)

Return the cost of `channel`. Default implementation accumulates the distances
between the source and sink addresses of the channel using `sa_struct.distance`.

Method List
-----------
$(METHODLIST)
"""
@propagate_inbounds function channel_cost(
        ::Type{<:Architecture},
        sa_struct::SAStruct,
        channel::TwoChannel
    )

    a = getaddress(sa_struct.nodes[channel.source])
    b = getaddress(sa_struct.nodes[channel.sink])
    distance = sa_struct.distance[a,b]

    return Float64(distance)
end

@propagate_inbounds function channel_cost(
        ::Type{<:Architecture}, 
        sa_struct::SAStruct, 
        channel::MultiChannel
    )

    cost = 0.0
    for src in channel.sources, snk in channel.sinks
        # Get the source and sink addresses
        a = getaddress(sa_struct.nodes[src])
        b = getaddress(sa_struct.nodes[snk])
        cost += sa_struct.distance[a,b]
    end
    return cost
end

address_cost(::Type{<:Architecture}, sa_struct::SAStruct, node::Node) = zero(Float64)
aux_cost(::Type{<:Architecture}, sa_struct::SAStruct) = zero(Float64)

map_cost(sa_struct::SAStruct{A}) where A = map_cost(A, sa_struct)
function map_cost(::Type{A}, sa_struct::SAStruct) where {A <: Architecture}
    cost = aux_cost(A, sa_struct)
    for i in eachindex(sa_struct.channels)
        cost += channel_cost(A, sa_struct, i)
    end
    for n in sa_struct.nodes
        cost += address_cost(A, sa_struct, n)
    end
    return cost
end

@propagate_inbounds function node_cost(
        ::Type{A}, 
        sa_struct::SAStruct, 
        index::Integer
    ) where {A <: Architecture}

    # Unpack node data type.
    n = sa_struct.nodes[index]
    cost = aux_cost(A, sa_struct)
    for channel in n.outchannels
        cost += channel_cost(A, sa_struct, channel)
    end
    for channel in n.inchannels
        cost += channel_cost(A, sa_struct, channel)
    end
    cost += address_cost(A, sa_struct, n)

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
        sa_struct::SAStruct, 
        i,
        j,
    ) where {A <: Architecture}

    cost = node_cost(A, sa_struct, i)
    # Get the two node types for calculating the cost of the second node.
    a = sa_struct.nodes[i]
    b = sa_struct.nodes[j]

    for channel in b.outchannels
        if !in(channel, a.inchannels)
            cost += channel_cost(A, sa_struct, channel)
        end
    end
    for channel in b.inchannels
        if !in(channel, a.outchannels)
            cost += channel_cost(A, sa_struct, channel)
        end
    end
    cost += address_cost(A, sa_struct, b)
    return cost
end
