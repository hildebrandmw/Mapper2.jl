module MapperGraphs

using Reexport
@reexport using LightGraphs

# Additions to the light graphs API
export  SparseDiGraph,
        source_vertices,
        sink_vertices,
        linearize,
        make_lightgraph

################################################################################
# Subgraph for for lightgraphs
################################################################################
struct AdjList{T}
    neighbors_in ::Vector{T}
    neighbors_out::Vector{T}
end

AdjList{T}() where T = AdjList(T[], T[])

struct SparseDiGraph{T}
    vertices::Dict{T,AdjList{T}}
end

SparseDiGraph{T}() where T = SparseDiGraph(Dict{T,AdjList{T}}())

LightGraphs.has_vertex(g::SparseDiGraph, v) = haskey(g.vertices, v)

function LightGraphs.add_vertex!(g::SparseDiGraph{T}, v) where T
    has_vertex(g, v) && return false
    g.vertices[v] = AdjList{T}()
    return true
end

function LightGraphs.add_edge!(g::SparseDiGraph, src, snk)
    has_vertex(g, src) || throw(KeyError(src))
    has_vertex(g, snk) || throw(KeyError(snk))
    push!(g.vertices[src].neighbors_out, snk)
    push!(g.vertices[snk].neighbors_in,  src)
    return nothing
end

LightGraphs.vertices(g::SparseDiGraph) = keys(g.vertices)
LightGraphs.outneighbors(g::SparseDiGraph, v) = g.vertices[v].neighbors_out
LightGraphs.inneighbors(g::SparseDiGraph, v)  = g.vertices[v].neighbors_in
LightGraphs.nv(g::SparseDiGraph) = length(g.vertices)

source_vertices(g::SparseDiGraph) = [v for v in vertices(g) if length(inneighbors(g,v)) == 0]
sink_vertices(g::SparseDiGraph) = [v for v in vertices(g) if length(outneighbors(g,v)) == 0]


"""
    linearize(g::SparseDiGraph{T}) where T

Return a Vector{T} of vertices of `g` in linearized traversal order if `g` is
linear. Throw error if `g` is not linear.
"""
function linearize(g::SparseDiGraph{T}) where T
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
    make_lightgraph(s::SparseDiGraph)

Given `s`, return a tuple `(g,d` where lightgraph `g` and dictionary `d`
where `g` is isomorphic to `s` and `d` maps vertices of `s` to vertices of `g`.
"""
function make_lightgraph(s::SparseDiGraph)
    g = DiGraph(nv(s))
    # Create a mapping dictionary
    d = Dict(v => i for (i,v) in enumerate(vertices(s)))
    # Iterate over edges, adding each edge to the lightgraph
    for i in vertices(s), j in outneighbors(s, i)
        add_edge!(g, d[i], d[j])
    end
    return g, d
end

end
