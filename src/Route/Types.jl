# Collection of basic types to use during routing for clarity.

"""
Type to access channels in the routing taskgraph. Essentially, it is just a 
wrapper for an integer, but typed to allow safer and clearer usage.
"""
struct ChannelIndex
    idx :: Int 
end

Base.getindex(A::AbstractArray, i::ChannelIndex) = getindex(A, i.idx)
Base.setindex!(A::AbstractArray, X, i::ChannelIndex) = setindex!(A, X, i.idx)

"""
Indices of a [`RoutingGraph`](@ref) that can serve as either start or stop
vertices (depending on the context) of one branch of a [`RoutingChannel`](@ref).
"""
struct PortVertices
    indices :: Vector{Int64}
end

Base.getindex(A::PortVertices, i) = getindex(A.indices, i)
Base.setindex!(A::PortVertices, X, i) = setindex!(A.incides, X, i)
Base.iterate(A::PortVertices, args...) = iterate(A.indices, args...)
Base.length(A::PortVertices) = length(A.indices)
