"""
    ismappable(::AbstractKC, c::Component)

The default criteria for a component being a mappable component is that is must
have an "attributes" field in its metadata (value should be a vector of strings)
and the length of that vector should be greater than 0.
"""
function ismappable(::Type{T}, c::Component) where {T <: AbstractKC}
    return haskey(c.metadata, "attributes") && length(c.metadata["attributes"]) > 0
end

"""
    isspecial(::Type{T}, t::TaskgraphNode) where {T <: AbstractKC}

Return `true` if the taskgraph node requires a special attribute and thus
needs special consideration for placement.

Throw error if node is missing a "required_attributes" field in its metadata.
"""
function isspecial(::Type{T}, t::TaskgraphNode) where {T <: AbstractKC}
    return oneofin(t.metadata["required_attributes"], _special_attributes)
end

"""
    isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode) where {T <: AbstractKC}

Return `true` if taskgraph nodes `a` and `b` are considered "equivalent" when
it comes to placement.
"""
function isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode) where {T <: AbstractKC}
    # Return true if the "required_attributes" are equal
    return a.metadata["required_attributes"] == b.metadata["required_attributes"]
end

"""
    canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: AbstractKC}

Return `true` if taskgraph node `t` and be mapped to component `c`.
"""
function canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: AbstractKC}
    return issubset(t.metadata["required_attributes"], c.metadata["attributes"])
end





################################################################################
# Methods for architectures with link weights
################################################################################
struct CostSAEdge <: AbstractSAEdge
    sources ::Vector{Int64}
    sinks   ::Vector{Int64}
    cost    ::Float64
end

function build_sa_edge(::Type{KCLink}, edge::TaskgraphEdge, node_dict)
    # Build up adjacency lists.
    # Sources in the task-graphs are strings so we can just use the
    # node-dictionary to convert them into integers.
    sources = [node_dict[s] for s in edge.sources]
    sinks   = [node_dict[s] for s in edge.sinks]
    # Assign the cost of the link using the "weight" parameter added by
    # one of the earlier transforms to the taskgraph
    cost    = edge.metadata["weight"]
    return CostSAEdge(sources, sinks, cost)
end

# Costed metric functions
function edge_cost(::Type{KCLink}, sa::SAStruct, edge)
    cost = 0.0
    for src in sa.edges[edge].sources, snk in sa.edges[edge].sinks
        # Get the source and sink addresses
        src_address = sa.nodes[src].address
        snk_address = sa.nodes[snk].address
        cost += sa.edges[edge].cost * sa.distance[src_address, snk_address]
    end
    return cost
end
