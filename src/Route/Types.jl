# Collection of basic types to use during routing for clarity.

struct ChannelIndex
    idx :: Int 
end

Base.getindex(A::AbstractArray, i::ChannelIndex) = getindex(A, i.idx)
Base.setindex!(A::AbstractArray, X, i::ChannelIndex) = setindex!(A, X, i.idx)

# Simple type for clarity sake.
struct PortVertices
    indices :: Vector{Int64}
end

Base.getindex(A::PortVertices, i) = getindex(A.indices, i)
Base.setindex!(A::PortVertices, X, i) = setindex!(A.incides, X, i)
Base.iterate(A::PortVertices, args...) = iterate(A.indices, args...)
Base.length(A::PortVertices) = length(A.indices)
