"""
Simple container representing a task in a taskgraph.
"""
struct TaskgraphNode
    "The name of this task."
    name :: String
    metadata :: Dict{String,Any}

    # Constructor
    TaskgraphNode(name; metadata = emptymeta()) = new(name, metadata)
end

"""
Simple container representing an edge in a taskgraph.
"""
struct TaskgraphEdge
    "Source task names."
    sources :: Vector{String}
    "Sink task names."
    sinks :: Vector{String}
    metadata :: Dict{String,Any}

    function TaskgraphEdge(source, sink; metadata = Dict{String,Any}())
        sources = wrap_vector(source)
        sinks   = wrap_vector(sink)
        return new(sources, sinks, metadata)
    end
end

"""
$(SIGNATURES)

Return the names of sources of a `TaskgraphEdge`.
"""
getsources(taskgraph_edge::TaskgraphEdge) = taskgraph_edge.sources

"""
$(SIGNATURES)

Return the names of sinks of a `TaskgraphEdge`.
"""
getsinks(taskgraph_edge::TaskgraphEdge) = taskgraph_edge.sinks

"""
Data structure encoding tasks and their relationships.
"""
struct Taskgraph
    "The name of the taskgraph"
    name :: String

    "Nodes in the taskgraph. Type: [`Dict{String, TaskgraphNode}`](@ref TaskgraphNode)"
    nodes :: Dict{String, TaskgraphNode}

    "Edges in the taskgraph. Type: [`Vector{TaskgraphEdge}`](@ref TaskgraphEdge)"
    edges :: Vector{TaskgraphEdge}

    """
    Outgoing adjacency list mapping node names to edge indices.
    Type: `Dict{String, Vector{Int64}}`
    """
    node_edges_out :: Dict{String, Vector{Int}}

    """
    Incoming adjacency list mapping node names to edge indices.
    Type: `Dict{String, Vector{Int64}}`
    """
    node_edges_in :: Dict{String, Vector{Int}}

    function Taskgraph(name = "noname")
        new(name,
            Dict{String,TaskgraphNode}(),
            TaskgraphEdge[],
            Dict{String,Vector{Int}}(),
            Dict{String,Vector{Int}}(),
        )
    end

    function Taskgraph(name :: String, nodes, edges)
        if eltype(nodes) != TaskgraphNode
            typer = TypeError(
                :Taskgraph,
                "Incorrect Node Element Type",
                TaskgraphNode,
                eltype(nodes)
            )

            throw(typer)
        end
        if eltype(edges) != TaskgraphEdge
            typer = TypeError(
                :Taskgraph,
                "Incorrect Edge Element Type",
                TaskgraphEdge,
                eltype(edges)
            )

            throw(typer)
        end
        # First - create the dictionary to store the nodes. Nodes can be
        # accessed via their name.
        nodes = Dict(n.name => n for n in nodes)
        # Initialize the adjacency lists with an entry for each node. Initialize
        # the values to empty arrays of edges so down-stream algortihms won't
        # have to check if an adjacency list exists for a node.
        edges = collect(edges)
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

# Allow construction without any name.
Taskgraph(nodes, edges) = Taskgraph("noname", nodes, edges)

################################################################################
# METHODS FOR THE TASKGRAPH
################################################################################
# -- Some accessor methods.

"""
$(SIGNATURES)

Return an iterator of [`TaskgraphNode`](@ref) yielding all nodes in `taskgraph`.
"""
getnodes(taskgraph::Taskgraph) = values(taskgraph.nodes)

"""
$(SIGNATURES)

Return an iterator of [`TaskgraphEdge`](@ref) yielding all edges in `taskgraph`.
"""
getedges(taskgraph::Taskgraph) = taskgraph.edges

"""
$(SIGNATURES)

Return the [`TaskgraphNode`](@ref) in `taskgraph` with `name`.
"""
getnode(taskgraph::Taskgraph, name::String) = taskgraph.nodes[name]

"""
$(SIGNATURES)

Return the [`TaskgraphEdge`](@ref) in `taskgraph` with `index`.
"""
getedge(taskgraph::Taskgraph, index::Integer) = taskgraph.edges[index]

# -- helpful query methods.
"""
$(SIGNATURES)

Return an iterator yielding all names of nodes in `taskgraph`.
"""
nodenames(taskgraph::Taskgraph) = keys(taskgraph.nodes)

"""
$(SIGNATURES)

Return the number of nodes in `taskgraph`.
"""
num_nodes(taskgraph::Taskgraph) = length(taskgraph.nodes)

"""
$(SIGNATURES)

Return the number of edges in `taskgraph`.
"""
num_edges(taskgraph::Taskgraph) = length(taskgraph.edges)

"""
$(SIGNATURES)

Return `Vector{TaskgraphNode}` of sources for `edge`.
"""
getsources(taskgraph::Taskgraph, edge::TaskgraphEdge) = (taskgraph.nodes[n] for n in getsources(edge))

"""
$(SIGNATURES)

Return `Vector{TaskgraphNode}` of sinks for `edge`.
"""
getsinks(taskgraph::Taskgraph, edge::TaskgraphEdge) = (taskgraph.nodes[n] for n in getsinks(edge))

"""
$(SIGNATURES)

Add a `node` to `taskgraph`. Error if node already exists.
"""
function add_node(taskgraph::Taskgraph, node::TaskgraphNode)
    if haskey(taskgraph.nodes, node.name)
        error("Task $(node.name) already exists in taskgraph.")
    end
    taskgraph.nodes[node.name] = node
    # Create adjacency list entries for the new nodes
    taskgraph.node_edges_out[node.name] = TaskgraphEdge[]
    taskgraph.node_edges_in[node.name]  = TaskgraphEdge[]
    return nothing
end

"""
$(SIGNATURES)

Add a `edge` to `taskgraph`.
"""
function add_edge(taskgraph::Taskgraph, edge::TaskgraphEdge)
    # Update the edge array
    push!(taskgraph.edges, edge)
    index = length(taskgraph.edges)
    # Update the adjacency lists.
    for source in edge.sources
        push!(taskgraph.node_edges_out[source], index)
    end
    for sink in edge.sinks
        push!(taskgraph.node_edges_in[sink], index)
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

"""
$(SIGNATURES)

Return `true` if `taskgraph` has a task named `node`.
"""
hasnode(taskgraph::Taskgraph, node::String) = haskey(taskgraph.nodes, node)

"""
$(SIGNATURES)

Return `Set{String}` of names of unique nodes that are the sink of an edges
starting at `node`.
"""
function outnode_names(taskgraph::Taskgraph, node)
    edges = out_edges(taskgraph, node)
    node_names = Set{String}()
    for edge in edges
        union!(node_names, getsinks(edge))
    end
    return node_names
end

"""
$(SIGNATURES)

Return [`Vector{TaskgraphNode}`](@ref TaskgraphNode) of unique nodes that are
the sink of an edge starting at `node`.
"""
function outnodes(taskgraph::Taskgraph, node)
    names = outnode_names(taskgraph, node)
    return [getnode(taskgraph, name) for name in names]
end

"""
$(SIGNATURES)

Return `Set{String}` of names of unique nodes that are the source of an edges
ending at `node`.
"""
function innode_names(taskgraph::Taskgraph, node)
    edges = in_edges(taskgraph, node)
    node_names = Set{String}()
    for edge in edges
        union!(node_names, getsources(edge))
    end
    return node_names
end

"""
$(SIGNATURES)

Return [`Vector{TaskgraphNode}`](@ref TaskgraphNode) of unique nodes that are
the source of an edge ending at `node`.
"""
function innodes(taskgraph::Taskgraph, node)
    names = innode_names(taskgraph, node)
    return [getnode(taskgraph, name) for name in names]
end

