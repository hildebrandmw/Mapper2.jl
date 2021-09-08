module MapperGraphs

using ..Mapper2.Helper
Helper.@SetupDocStringTemplates

using LightGraphs

# Additions to the light graphs API
export SparseDiGraph, source_vertices, sink_vertices, linearize, make_lightgraph

# Manually export the needed items from LightGraphs instead of 
# Reexporting to:
# 1. Not pollute the namespace with random unused names
# 2. Avoid Documentor looking at all the docstrings in LightGraphs and
# throwing a million "missing docstring" errors.

# Graph types
export AbstractGraph,
    SimpleDiGraph,
    DiGraph,
    # Mutating methods
    add_edge!,
    add_vertex!,
    add_vertices!,
    # Iterating methods
    edges,
    vertices,
    # Query Methods
    nv,
    ne,
    outneighbors,
    inneighbors,
    has_edge,
    has_vertex,
    src,
    dst,
    # Analysis
    is_weakly_connected,
    has_path

################################################################################
# Subgraph for for lightgraphs
################################################################################
struct AdjacencyList{T}
    neighbors_in::Vector{T}
    neighbors_out::Vector{T}
end

AdjacencyList{T}() where {T} = AdjacencyList(T[], T[])

"""
Graph representation with arbitrary vertices of type `T`.
"""
struct SparseDiGraph{T}
    vertices::Dict{T,AdjacencyList{T}}
end

SparseDiGraph{T}() where {T} = SparseDiGraph(Dict{T,AdjacencyList{T}}())

LightGraphs.has_vertex(g::SparseDiGraph, v) = haskey(g.vertices, v)

function LightGraphs.add_vertex!(g::SparseDiGraph{T}, v) where {T}
    has_vertex(g, v) && return false
    g.vertices[v] = AdjacencyList{T}()
    return true
end

function LightGraphs.add_edge!(g::SparseDiGraph, src, snk)
    has_vertex(g, src) || throw(KeyError(src))
    has_vertex(g, snk) || throw(KeyError(snk))
    push!(g.vertices[src].neighbors_out, snk)
    push!(g.vertices[snk].neighbors_in, src)
    return nothing
end

LightGraphs.vertices(g::SparseDiGraph) = keys(g.vertices)
LightGraphs.outneighbors(g::SparseDiGraph, v) = g.vertices[v].neighbors_out
LightGraphs.inneighbors(g::SparseDiGraph, v) = g.vertices[v].neighbors_in
LightGraphs.nv(g::SparseDiGraph) = length(g.vertices)

"""
    source_vertices(graph::SparseDiGraph{T}) :: Vector{T} where T

Return the vertices of `graph` that have no incoming edges.
"""
function source_vertices(g::SparseDiGraph)
    return [v for v in vertices(g) if length(inneighbors(g, v)) == 0]
end

"""
    sink_vertices(graph::SparseDiGraph{T}) :: Vector{T} where T

Return the vertices of `graph` that have no outgoing edges.
"""
function sink_vertices(g::SparseDiGraph)
    return [v for v in vertices(g) if length(outneighbors(g, v)) == 0]
end

"""
    linearize(graph::SparseDiGraph{T}) where T

Return a Vector{T} of vertices of `graph` in linearized traversal order if 
`graph` is linear. Throw error if `ggraph` is not a linear graph.
"""
function linearize(g::SparseDiGraph{T}) where {T}
    # Do a check for an empty graph.
    if nv(g) == 0
        return T[]
    end

    sv = source_vertices(g)
    length(sv) != 1 && error("Expected 1 source vertex. Found $(length(sv)).")
    vertices = T[first(sv)]
    neighbors = outneighbors(g, last(vertices))
    while length(neighbors) > 0
        if length(neighbors) > 1
            error("""
                Vertex $(last(vertices)) has $(length(neighbors)) neighbors.
                Expected 1.
                """)
        end
        push!(vertices, first(neighbors))
        neighbors = outneighbors(g, last(vertices))
    end
    return vertices
end

"""
    make_lightgraph(graph::SparseDiGraph{T}) where T :: (SimpleDiGraph, Dict{T,Int})

Return tuple `(g, d)` where `g :: SimpleDiGraph` is a `LightGraph` ismorphic
to `graph` and `d` maps vertices of `graph` to vertices of `g`.
"""
function make_lightgraph(s::SparseDiGraph)
    g = DiGraph(nv(s))
    # Create a mapping dictionary
    d = Dict(v => i for (i, v) in enumerate(vertices(s)))
    # Iterate over edges, adding each edge to the lightgraph
    for i in vertices(s), j in outneighbors(s, i)
        add_edge!(g, d[i], d[j])
    end
    return g, d
end

end
