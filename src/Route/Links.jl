# Default link for recording the information about routing links.
struct RoutingLink <: AbstractRoutingLink
    channels::Vector{Int64}
    cost    ::Float64
    capacity::Int64
end

RoutingLink(;cost = 1.0, capacity = 1) = RoutingLink(Int[], cost, capacity)

# Accessor functions
channels(a::AbstractRoutingLink)   = a.channels
cost(a::AbstractRoutingLink)       = a.cost
capacity(a::AbstractRoutingLink)   = a.capacity
occupancy(a::AbstractRoutingLink)  = length(a.channels)

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

function annotate(arch::TopLevel{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    @info "Annotating Graph Links"
    maprev = rev_dict(rg.map)

    # Initialize this to any. We'll clean it up later.
    routing_links_any = Vector{Any}(nv(rg.graph))

    for (i, path) in maprev
        routing_links_any[i] = annotate(A, arch[path])
    end
    # Clean up types
    routing_links = typeunion(routing_links_any)

    @debug "Type of Routing Link Annotations: $(typeof(routing_links))"
    return routing_links
end
