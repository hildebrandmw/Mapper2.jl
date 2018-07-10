
"""
    struct TaskgraphNode

Simple container representing a node in a taskgraph. Miscellaneous data should
be stored in the `metadata` field.

# Fields:
* `name::String` - The name of the task.
* `metadata::Dict{String,Any}` - Container for storing any additional
    information with the type to build datastructure down stream.

# Constructor
    TaskgraphNode(name, metadata = Dict{String,Any}())

"""
struct TaskgraphNode
    name    ::String
    metadata::Dict{String,Any}
    # Constructor
    TaskgraphNode(name, metadata = Dict{String,Any}()) = new(name, metadata)
end

"""
    struct TaskgraphEdge

Simple container representing an edge in a taskgraph. Miscellaneous data should
be stored in the `metadatea` field.

# Fields
* `sources::Vector{String}` - Names of `TaskgraphNodes`s that are sources for
    this edge.
* `sinks::Vector{String}` - Names of `TaskgraphNode`s that are destinations
    for this edge.
* `metadata::Dict{String,Any}` - Container for storing any additional
    information with the type to build datastructure down stream.

# Constructor
    TaskgraphEdge(source, sink, metadata = Dict{String,Any}())

Arguments `source` and `sink` may either be of type `String` or `Vector{String}`.
"""
struct TaskgraphEdge
    sources ::Vector{String}
    sinks   ::Vector{String}
    metadata::Dict{String,Any}

    function TaskgraphEdge(source, sink, metadata = Dict{String,Any}())
        sources = wrap_vector(source)
        sinks   = wrap_vector(sink)
        return new(sources, sinks, metadata)
    end
end

"Return the names of sources of a `TaskgraphEdge`."
getsources(t::TaskgraphEdge) = t.sources

"Return the names of sinks of a `TaskgraphEdge`."
getsinks(t::TaskgraphEdge)   = t.sinks

"""
    struct Taskgraph

Data structure encoding tasks and their relationships.

# Fields
* `name::String` - The name of the taskgraph.
* `nodes::Dict{String, TaskgraphNode}` - Tasks within the taskgraph. Keys are
    the instance names of the node, value is the data structure.
* `edges::Vector{TaskgraphEdge}` - Collection of edges between `TaskgraphNode`s.
* `node_edges_out::Dict{String,Vector{TaskgraphEdge}}` - Fast adjacency lookup.
    Given a task name, returns a collection of `TaskgraphEdge` that have the
    corresponding task as a source.
* `node_edges_in::Dict{String,Vector{TaskgraphEdge}}` - Fast adjacency lookup.
    Given a task name, returns a collection of `TaskgraphEdge` that have the
    corresponding task as a sink.

# Constructor
    Taskgraph(name, node_container, edge_container)

Return a `TaskGraph` with the given name, nodes, and edges. Arguments
`node_container` and `edge_container` must have elements of type
`TaskgraphEdge` and `TaskgraphNode` respectively.
"""
struct Taskgraph
    name            ::String
    nodes           ::Dict{String, TaskgraphNode}
    edges           ::Vector{TaskgraphEdge}
    node_edges_out  ::Dict{String, Vector{Int}}
    node_edges_in   ::Dict{String, Vector{Int}}

    function Taskgraph(name = "noname")
        new(name,
            Dict{String,TaskgraphNode}(),
            TaskgraphEdge[],
            Dict{String,Vector{Int}}(),
            Dict{String,Vector{Int}}(),
        )
    end

    function Taskgraph(name, node_container, edge_container)
        if eltype(node_container) != TaskgraphNode
            typer = TypeError(
                  :Taskgraph,
                  "Incorrect Node Element Type",
                  TaskgraphNode,
                  eltype(node_container))

            throw(typer)
        end
        if eltype(edge_container) != TaskgraphEdge
            typer = TypeError(
                  :Taskgraph,
                  "Incorrect Edge Element Type",
                  TaskgraphEdge,
                  eltype(edge_container))

            throw(typer)
        end
        # First - create the dictionary to store the nodes. Nodes can be
        # accessed via their name.
        nodes = Dict(n.name => n for n in node_container)
        # Initialize the adjacency lists with an entry for each node. Initialize
        # the values to empty arrays of edges so down-stream algortihms won't
        # have to check if an adjacency list exists for a node.
        edges = collect(edge_container)
        node_edges_out = Dict(name => Int[] for name in keys(nodes))
        node_edges_in  = Dict(name => Int[] for name in keys(nodes))
        # Iterate through all edges - grow adjacency lists correctly.
        for (index, edge) in enumerate(edges)
            for source in edge.sources
                push!(node_edges_out[source], index)
            end
            for sink in edge.sinks
                push!(node_edges_in[sink], index)
            end
        end
        # Return the data structure
        return new(
            name,
            nodes,
            edges,
            node_edges_out,
            node_edges_in,
        )
    end
end

################################################################################
# METHODS FOR THE TASKGRAPH
################################################################################
# -- Some accessor methods.
getnodes(t::Taskgraph) = values(t.nodes)
getedges(t::Taskgraph) = t.edges
getnode(t::Taskgraph, node::String) = t.nodes[node]
getedge(t::Taskgraph, i::Integer) = t.edges[i]

# -- helpful query methods.
nodenames(t::Taskgraph) = keys(t.nodes)
num_nodes(t::Taskgraph) = length(getnodes(t))
num_edges(t::Taskgraph) = length(getedges(t))

getsources(t::Taskgraph, te::TaskgraphEdge) = (t.nodes[n] for n in getsources(te))
getsinks(t::Taskgraph, te::TaskgraphEdge) = (t.nodes[n] for n in getsinks(te))

"""
    add_node(t::Taskgraph, task::TaskgraphNode)

Add a `task` to `t`. Error if node already exists.
"""
function add_node(t::Taskgraph, task::TaskgraphNode)
    if haskey(t.nodes, task.name)
        error("Task $(task.name) already exists in taskgraph.")
    end
    t.nodes[task.name] = task
    # Create adjacency list entries for the new nodes
    t.node_edges_out[task.name] = TaskgraphEdge[]
    t.node_edges_in[task.name]  = TaskgraphEdge[]
    return nothing
end

"""
    add_edge(t::Taskgraph, edge::TaskgraphEdge)

Add a `edge` to `t`. Multiple edges from the same source to destination are
allowed.
"""
function add_edge(t::Taskgraph, edge::TaskgraphEdge)
    # Update the edge array
    push!(t.edges, edge)
    index = length(t.edges)
    # Update the adjacency lists.
    for source in edge.sources
        push!(t.node_edges_out[source], index)
    end
    for sink in edge.sinks
        push!(t.node_edges_in[sink], index)
    end
    return nothing
end


# Methods for accessing the adjacency lists
out_edges(t::Taskgraph, task::String) = [t.edges[i] for i in t.node_edges_out[task]]
out_edges(t::Taskgraph, task::TaskgraphNode) = out_edges(t, task.name)

out_edge_indices(t::Taskgraph, task::String) = t.node_edges_out[task]
out_edge_indices(t::Taskgraph, task::TaskgraphNode) = out_edge_indices(t, task.name)

in_edges(t::Taskgraph, task::String) = [t.edges[i] for i in t.node_edges_in[task]]
in_edges(t::Taskgraph, task::TaskgraphNode) = in_edges(t, task.name)

in_edge_indices(t::Taskgraph, task::String) = t.node_edges_in[task]
in_edge_indices(t::Taskgraph, task::TaskgraphNode) = in_edge_indices(t, task.name)

hasnode(t::Taskgraph, node::String) = haskey(t.nodes, node)

@doc """
    out_edges(t::Taskgraph, task::Union{String,TaskgraphNode})

Return `Vector{TaskgraphEdge}` for which `task` is a source."
""" out_edges

@doc """
    in_edges(t::Taskgraph, task::Union{String,TaskgraphNode})

Return `Vector{TaskgraphEdge}` for which `task` is a sink.
""" in_edges

@doc """
    hasnode(t::Taskgraph, node::String)

Return `true` if `t` has a task named `node`.
""" hasnode

@doc """
    outneighbors(t::Taskgraph, node)

Return a collection of nodes from `t` for which are the sink of an edge starting
at `node`.
""" outnodes

@doc """
    inneighbors(t::Taskgraph, node)

    Return a collection of nodes from `t` for which are the source of an edge ending
at `node`.
""" innodes

function outnode_names(t::Taskgraph, node)
    edges = out_edges(t, node)
    node_names = Set{String}()
    for edge in edges
        union!(node_names, getsinks(edge))
    end
    return node_names
end

function outnodes(t::Taskgraph, node)
    names = outnode_names(t, node)
    return [getnode(t, name) for name in names]
end

function innode_names(t::Taskgraph, node)
    edges = in_edges(t, node)
    node_names = Set{String}()
    for edge in edges
        union!(node_names, getsources(edge))
    end
    return node_names
end

function innodes(t::Taskgraph, node)
    names = innode_names(t, node)
    return [getnode(t, name) for name in names]
end

