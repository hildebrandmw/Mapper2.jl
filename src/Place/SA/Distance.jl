"""
Abstract distance type for placement.

API
---
* [`getdistance`](@ref)
* [`maxdistance`](@ref)

Basic Implementation
--------------------
* [`BasicDistance`](@ref)
"""
abstract type SADistance end

##################
# SADistance API #
##################

"""
    getdistance(A::SADistance, a, b)

Return the distance from `a` to `b` with respect to `A`. Both `a` and `b` will
implement [`getaddress`](@ref).

Method List
-----------
$(METHODLIST)
"""
function getdistance end

"""
    maxdistance(sa_struct, A::SADistance)

Return the maximum distance value of that occurs in `sa_struct` using the
distance metric imposed by `A`.

Method List
-----------
$(METHODLIST)
"""
function maxdistance end


################################################################################
# Basic Distance
################################################################################

"""
    $(SIGNATURES)

Basic implementation of [`SADistance`](@ref). Constructs a look up table of
distances between all address pairs. Addresses have a distance of 1 if there
exists even one link between components at those addresses.
"""
struct BasicDistance{D} <: SADistance
    """
    Simple look up table indexed by pairs of addresses. Returned value is the
    distance between the two addresses.

    If an architecture has dimension "N", then the dimension of `table` is `2N`.
    """
    table :: Array{UInt8, D}
end

# Unwrap and
@propagate_inbounds @inline function getdistance(A::BasicDistance, a, b)
    A.table[getaddress(a), getaddress(b)]
end
maxdistance(sa_struct, A::BasicDistance) = maximum(A.table)

################################################################################
# BFS Routines for building the distance look up table
################################################################################
function BasicDistance(toplevel::TopLevel, pathtable::PathTable)
    # The data type for the LUT
    element_type = UInt8
    # Pre-allocate the table. Get the size of the `toplevel` to figure out
    # how big to make the table.
    #
    # Since we want to get the distance between pairs of addresses, we need
    # to double size of `toplevel`.
    dims = size(toplevel)
    pretable = fill(typemin(element_type), dims..., dims...)

    # Get the adjacency information from toplevel.
    neighbors = neighbor_dict(toplevel)

    @debug "Building Distance Table"

    # Get all-pairs shorest path from the adjacency lists. For each pair
    # of addresses "a", "b", "table[a,b]" will be the distance from "a" to "b"
    for address in keys(neighbors)
        bfs!(pretable, address, neighbors)
    end

    table = expand(pretable, toplevel, pathtable)
    return BasicDistance(table)
end

expand(pretable::Array{T}, ::TopLevel{D}, ::PathTable{D}) where {T,D} = pretable

function expand(
            pretable::Array{T},
            toplevel::TopLevel{D},
            pathtable::PathTable{N},
        ) where {T,D,N}

    # Just Replicate the table.
    fullsize = size(pathtable)
    table = fill(typemin(T), fullsize..., fullsize...)
    table = map(CartesianIndices((fullsize..., fullsize...))) do idx
        a, b = half(Tuple(idx))
        return pretable[Base.tail(a)..., Base.tail(b)...]
    end
    return table
end
half(x::NTuple{N}) where N = x[1:(N>>1)], x[((N>>1)+1):N]

#=
Simple data structure for keeping track of costs associated with addresses
Gets put the the queue for the BFS.
=#
struct CostAddress{U,D}
    cost::U
    address::Address{D}
end

# Implementation note:
# This function is only correct if the cost of each link is 1. If cost can vary,
# will have to code this using some kind of shortest path formulation.
function bfs!(distance::Array{U,N}, source::Address{D}, neighbors) where {U,N,D}
    # Create a queue for visiting addresses. Add source to get into the loop.
    q = Queue{CostAddress{U,D}}()
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items to avoid visiting the same address twice
    # and mark the initial address as "seen".
    seen = Set{Address{D}}()
    push!(seen, source)

    # Basic BFS.
    while !isempty(q)
        u = dequeue!(q)
        distance[source, u.address] = u.cost
        for v in neighbors[u.address]
            in(v, seen) && continue

            enqueue!(q, CostAddress(u.cost + one(U), v))
            push!(seen, v)
        end
    end

    return nothing
end

function neighbor_dict(toplevel::TopLevel)
    @debug "Building Neighbor Table"
    # Get the connected component dictionary
    cc = MapperCore.connected_components(toplevel)

    # Addresses may be zero or negative, but since we're using an array as our
    # underlying data structure, we have to shift the whole array to addresses
    # start at 1.
    #
    # Get this offset amount and apply it to the array.
    #
    # Wrap the offset in a Ref to ensure the broadcast treats it as a scalar.
    offset = getoffset(toplevel)
    return Dict(a + offset => collect(s) .+ Ref(offset) for (a,s) in cc)
end
