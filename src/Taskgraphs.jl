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

