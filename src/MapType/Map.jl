#=
The Map is going to be the top level data structure - containing:

1. The Architecture model
2. The Task-Graph
3. Mapping information between the taskgraph and architecture
4. All miscelaneous data types needed to spawn off the specialized datastructures
    needed for placement, routing, etc.

The big idea in this project is to make selection of algorithms, metrics, and
algorithm parameters be done via Julia's type dispatch system. That is, different
algorithms/parameters will be selected by storing a type corresponding to those
parameters in the top level data structure.

When lower level routines such as the simulated annealing placer are launched,
these types can be unpacked to dispatch to the correct functions.

Use of the function-wrapper technique should probably be used to ensure that
when the kernel functions are called, everything is type stable.
=#

#=
How to make the Mapping data structure to record data what nodes get mapped
to which components and how communication edges are routed through whatever
routing network is present on the architecture.

OPTION 1 - Store everything as a dictionary. Something like:

    mutable struct Mapping
        nodes::Dict{String, Dict{String,Any}}
        edges::Dict{Int64,  Dict{String,Any}}
    end

This has an advantage in that it is the most flexible approach and allows
anything and everything to be store. The down side is that we can't rely on
any special type-dispatch to automatically do things for us.

Another advantage of this approach is that it is natively JSON serializable
and will allow for easy - human readable storage. However, algorithms that 
interact with the dictionaries can get tedious.

OPTION 2 - Have some fields for things that will be common. For example, we can
think of having something like:

    mutable struct NodeMap{D}
        address     ::Address{D}
        component   ::String
        metadata    ::Dict{String,Any}
    end

To store the mapping of tasks to components. The advantage of this is that we
can rely on the consistency of the data structure to avoid some checks in
routines using the Mapping data structure. Unfortunately - this is not natively
JSON serializable - but it wouldn't be hard to write a simple routine that
can serialize and deserialize this structure for us.

Things to think about:

1. Will we ever run into nodes that are not mapped to a component?

Probably not - even if this does show up - these "shadow nodes" can probably be
mapped to some dummy addresses and component.

2. What if a node is mapped to multiple components?

I think that any instance of this can be solved by breaking the node into the
correct number of sub-nodes and dealing this with at a higher level of 
abstraction. 

Decision: Go with option 2. Will allow much of the code to be cleaner while
    still allowing a high degree of flexibility. Plus - it's more consistent
    with the rest of the mapper.
=#

################################################################################
# NodeMap data structure.
################################################################################
# Keeps track of where nodes in the taskgraph are mapped to the architecture
# as well as any applicable metadata.
mutable struct NodeMap{D}
    path        ::AddressPath{D}
    metadata    ::Dict{String,Any}

    function NodeMap(path::AddressPath{D}; 
                     metadata = Dict{String,Any}()) where D
        return new{D}(path, metadata)
    end
    NodeMap{D}() where D = new{D}(AddressPath{D}(), Dict{String,Any}())
end

#-- Methods
getpath(nodemap::NodeMap) = nodemap.path

mutable struct EdgeMap
    path        ::Vector{Any}
    metadata    ::Dict{String,Any}
    #-- constructors
    EdgeMap(path::Vector{Any}; metadata = Dict{String,Any}()) = new(path, metadata)
    EdgeMap() = new(Any[], Dict{String,Any}())
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
