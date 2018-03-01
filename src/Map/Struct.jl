################################################################################
# NodeMap data structure.
################################################################################
# Keeps track of where nodes in the taskgraph are mapped to the architecture
# as well as any applicable metadata.
mutable struct NodeMap{D}
    path        ::AddressPath{D}
    metadata    ::Dict{String,Any}

    function NodeMap(path::AddressPath{D}; metadata = emptymeta()) where D
        return new{D}(path, metadata)
    end
    NodeMap{D}() where D = new{D}(AddressPath{D}(), emptymeta())
end


#-- Methods
getpath(nodemap::NodeMap) = nodemap.path

mutable struct EdgeMap
    path        ::SparseDiGraph{Any}
    metadata    ::Dict{String,Any}

    #-- constructors
    function EdgeMap(path::SparseDiGraph; metadata = emptymeta()) 
        return new(path, metadata)
    end
    EdgeMap() = new(SparseDiGraph{Any}(), emptymeta())
end
getpath(edgemap::EdgeMap) = edgemap.path

"""
Flexible data structure recording the mapping of nodes and edges in the taskgraph
to elements in the top level.
"""
mutable struct Mapping{D}
    nodes::Dict{String, NodeMap{D}}
    edges::Vector{EdgeMap}
end

getpath(m::Mapping, nodename::String) = getpath(m.nodes[nodename])
getpath(m::Mapping, i::Integer) = getpath(m.edges[i])
Base.getindex(m::Mapping, i::Integer) = m.edges[i]
Base.setindex!(m::Mapping, v::EdgeMap, i::Integer) = setindex!(m.edges, v, i)

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
                options = Dict{Symbol,Any}(),
                metadata = Dict{String,Any}(),) where {A,D}

    # Create a new Mapping data type for the new map
    # Get the node names
    nodes = Dict(n => NodeMap{D}() for n in nodenames(taskgraph)) 
    edges = [EdgeMap() for i = 1:num_edges(taskgraph)]
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
