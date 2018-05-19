################################################################################
# NodeMap data structure.
################################################################################
# Keeps track of where nodes in the taskgraph are mapped to the architecture
# as well as any applicable metadata.
"""
Data structure recording the mapping of nodes and edges in the taskgraph
to elements in the TopLevel.
"""
const PPLC = Union{Path{Link},Path{Port},Path{Component}}
mutable struct Mapping
    nodes::Dict{String,Path{Component}}
    edges::Vector{SparseDiGraph{PPLC}}
end

getpath(m::Mapping, nodename::String) = m.nodes[nodename]
getpath(m::Mapping, i::Integer)       = m.edges[i]
Base.setindex!(m::Mapping, v, i::Integer) = setindex!(m.edges, v, i)


"""
Top level data structure. Summary of parameters:

* `A` - The architecture type used for the mapping.
* `D` - The number of dimensions in the architecture (will usually be 2 or 3).

# Fields
* `architecture::TopLevel{A,D}` - The architecture the taskgraph is mapped to.
* `taskgraph::Taskgraph` - Traskgraph to be mapped.
* `options::Dict{Symbol,Any}` - Miscellaneous runtime options.
* `mapping::Mapping` - Data structure recording how the taskgraph is mapped
    to the architecture.

# Constructor
    NewMap(a::TopLevel{A,D}, t::Taskgraph, options = Dict{Symbol,Any}())
"""
mutable struct Map{A,D}
    architecture::TopLevel{A,D}
    taskgraph   ::Taskgraph
    options     ::Dict{Symbol, Any}
    mapping     ::Mapping
    metadata    ::Dict{String,Any}
end

function NewMap(architecture::TopLevel{A,D}, 
                taskgraph   ::Taskgraph;
                options     = Dict{Symbol,Any}(),
                metadata    = Dict{String,Any}(),) where {A,D}

    # Create a new Mapping data type for the new map
    # Get the node names
    nodes = Dict(n => Path{Component}() for n in nodenames(taskgraph))
    edges = [SparseDiGraph{PPLC}() for i in 1:num_edges(taskgraph)]
    mapping = Mapping(nodes, edges)
    return Map(
        architecture,
        taskgraph,
        options,
        mapping,
        metadata,
      )
end

################################################################################
# Methods for interacting with the Map.
################################################################################
getpath(m::Map, nodename::String) = getpath(m.mapping, nodename)
getpath(m::Map, i::Integer) = getpath(m.mapping, i)

function isused(m::Map{A,D}, addr::CartesianIndex{D}) where {A,D}
    for path in values(m.mapping.nodes)
        getaddress(m.architecture, path) == addr && return true
    end
    return false
end

function gettask(m::Map{A,D}, addr::CartesianIndex{D}) where {A,D}
    for (taskname, path) in m.mapping.nodes
        if getaddress(m.architecture, path) == addr
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
