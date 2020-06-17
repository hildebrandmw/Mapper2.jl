################################################################################
# NodeMap data structure.
################################################################################
# Keeps track of where nodes in the taskgraph are mapped to the architecture
# as well as any applicable metadata.
const PPLC = Union{Path{Link},Path{Port},Path{Component}}

"""
Record of how [`Taskgraph`](@ref)s and [`TaskgraphEdge`](@ref)s in a
[`Taskgraph`](@ref) map to a [`TopLevel`](@ref).
"""
mutable struct Mapping
    """
    `Dict{String, Path{Component}}` - Takes a node name and returns the path
    to the [`Component`](@ref) where that node is mapped.
    """
    nodes::Dict{String,Path{Component}}

    """
    `Vector{SparseDiGraph{Union{Path{Link},Path{Port},Path{Component}}}}` -
    Takes a integer index for an edge in the parent [`Taskgraph`](@ref) and
    returns a graph whose node types `Path`s to architectural compoennts.o

    Edge connectivity in the graph describes how the [`TaskgraphEdge`](@ref) is
    routed through the [`TopLevel`](@ref)
    """
    edges::Vector{SparseDiGraph{PPLC}}
end

getpath(m::Mapping, nodename::String) = m.nodes[nodename]
getpath(m::Mapping, i::Integer)       = m.edges[i]
Base.setindex!(m::Mapping, v, i::Integer) = setindex!(m.edges, v, i)


"""
Top level data structure. Summary of parameters:

* `T` - The [`RuleSet`](@ref) used to control placement and routing.
* `D` - The number of dimensions in the architecture (will usually be 2 or 3).
"""
mutable struct Map{D, T <: RuleSet}
    "[`RuleSet`](@ref) for assigning `taskgraph` to `toplevel`."
    ruleset :: T

    "[`TopLevel{A,D}`](@ref) - The `TopLevel` to be used for the mapping."
    toplevel::TopLevel{D}

    "The [`Taskgraph`](@ref) to map to the `toplevel`."
    taskgraph   ::Taskgraph
    options     ::Dict{Symbol, Any}

    "How `taskgraph` is mapped to `toplevel`."
    mapping     ::Mapping
    metadata    ::Dict{String,Any}
end

function Map(
        ruleset::T,
        toplevel::TopLevel{D},
        taskgraph   ::Taskgraph;
        options     = Dict{Symbol,Any}(),
        metadata    = Dict{String,Any}(),
    ) where {T <: RuleSet,D}

    # Create a new Mapping data type for the new map
    # Get the node names
    nodes = Dict(n => Path{Component}() for n in nodenames(taskgraph))
    edges = [SparseDiGraph{PPLC}() for i in 1:num_edges(taskgraph)]
    mapping = Mapping(nodes, edges)
    return Map(
        ruleset,
        toplevel,
        taskgraph,
        options,
        mapping,
        metadata,
      )
end

rules(map::Map) = map.ruleset

function Base.show(io::IO, map::Map{T,D}) where {T,D}
    print(io, "Map{$T,$D} with $(num_nodes(map.taskgraph)) nodes")
    return nothing
end

################################################################################
# Methods for interacting with the Map.
################################################################################
getpath(m::Map, nodename::String) = getpath(m.mapping, nodename)
getpath(m::Map, i::Integer) = getpath(m.mapping, i)
getaddress(map::Map, nodename::String) = getaddress(map.toplevel, getpath(map, nodename))

function isused(m::Map{D}, addr::CartesianIndex{D}) where D
    for path in values(m.mapping.nodes)
        getaddress(m.toplevel, path) == addr && return true
    end
    return false
end

function gettask(m::Map{D}, addr::CartesianIndex{D}) where D
    for (taskname, path) in m.mapping.nodes
        if getaddress(m.toplevel, path) == addr
            return  getnode(m.taskgraph, taskname)
        end
    end
    return nothing
end

################################################################################
# Saving/loading
################################################################################

function makejls(filepath)
    dir, file = splitdir(filepath)

    filename = "$(first(split(file, "."))).jls"
    finalpath = joinpath(dir, filename)
    return finalpath
end

function save(m::Map, filepath)
    f = open(makejls(filepath), "w")
    serialize(f, m.mapping)
    close(f)
end

function load(m::Map, filepath)
    f = open(makejls(filepath), "r")
    mapping = deserialize(f)
    close(f)
    # bind deserialized result
    m.mapping = mapping
end
