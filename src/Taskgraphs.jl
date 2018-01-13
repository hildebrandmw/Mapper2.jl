#=
Simple taskgraph structure for the mapper. In general, I will try to keep this
structure as minimal as possible while keeping flexibility (meaning, we'll
still have the "metadata" field for tracking miscelaneous data).

QUESTION: How to make sure the right data is provided with the taskgraph
depending on the options?

1. Make each routine that uses the taskgraph search for the required data
and throw an error when it is not found. Requires heavy documentation about
what data has to be supplied with each link/task.

2. Have subroutines supply defaults where appropriate and then throw an error
if a required field is not found. This is probably better than just throwing an
error because types like links can have a reasonable cost default of 1.0, but
tasks definitely need to specify what types of components they can be mapped
to (thinking in terms of the workflow present in the original Mapper).

DECISION: Go with option 2. Will allow for more minimal taskgraphs it that
is desired. Routines might get a little more complicated but hopefully not too
much more.

QUESTION: Will I want to embed types in the 'metadata' field - and if so - how
do I do it because the types that can be represented in a JSON field are limited.

1. Have a finisher routine that takes a type specified at some higher level to
do the dispatch. Finisher can do things like convert string key words and other
arguments to their repsective types. Custom types in metadata dict might not
necessarily be needed.

2. Limit the capabilities of Mapper2 to not have custom types in the metadata
dictionary fields. Would probably keep downstream items simpler.

DECISION: Use option 1. Shouldn't be too hard to implement - custom finisher can
just be the identity function and won't be too hard to process.

QUESTION: Need to think about how to treat nodes that are neighbor in the
directed hypergraph sense.

Do I have special methods for common source, common sink, source -> sink, and
sink -> source adjacency lists? What's the best way of doing this? 

1. Four separate functions - Makes it very clear what is desired. Each function
is easy to write.

2. One super function with key work arguments - can potentially be awkward to
call but allows for a lot of expressiveness.

3. Combination approach - one super function that calls the four sub functions
to do the heavy lifting.

TENTATIVE DECISION: Maybe to option 3 - use a dictionary for function dispatch
and filter results.

################################################################################
STRUCTURE OF THE TAKGRAPH DATA STRUCTURE

Taskgraph should be more minimalistic than the taskgraph for the original mapper.
Maybe limit fields to

    - name
    - node data types
    - edge data types

Structure should NOT have the architecture as a field as in the original mapper.
This was a terrible idea and should not be repeated.

Desirable properties:
    - O(1) lookup of tasks by name
    - O(1) lookup of task adjacency lists by name.
       This can either be done by:
        1. Recording the edges assigned to each task and getting adjacency lists
        by iterating through the destinations of each outgoing link and sources
        of each incoming link.

        2. Keeping an adjacency list for each node directly.

        Go with option 1 as it is more flexible and allows for hypergraph
        structures. May potentially need to do some filtering of redundant
        neighbors in the case that one task has multiple edges to another task.

    How to implement: Probably make an auxiliary dictionary that maps task names
    to a vector of edges. Dictionary can be constructed when the whole data
    structure is constructed. This is probably the simplest way to do things.
    Traversing the datastructure might take a while - but task graphs are only
    on the order of 1000s of nodes so this shouldn't be a problem.

    If graph traversal becomes a problem, we can start thinking about more
    complicated implementations that hopefully won't change the core API.

    - Taskgraph type should not have any mapping information stored with it
    to keep it immutable.

    - Need to have edges readily accessible for storing what routing resources
    are used by each edge.
=#

module Taskgraphs

using ..Mapper2: Debug
using IterTools

export  AbstractTaskgraphConstructor,
        TaskgraphNode,
        TaskgraphEdge,
        Taskgraph,
        # Methods
        getsources,
        getsinks,
        apply_transforms,
        get_transforms,
        getnodes,
        getedges,
        getnode,
        getedge,
        nodenames,
        num_nodes,
        num_edges,
        add_node,
        add_edge,
        out_edges,
        in_edges,
        hasnode,
        out_nodes


# Type for choosing the constructor.
abstract type AbstractTaskgraphConstructor end

"""
Nodes of the taskgraph.
"""
mutable struct TaskgraphNode
    name    ::String
    metadata::Dict{String,Any}
    """
        TaskgraphNode(name, metadata = Dict{String,Any}())

    Create a new `TaskgraphNode` with optional metadata.
    """
    function TaskgraphNode(name, metadata = Dict{String,Any}())
        return new(name, metadata)
    end
end

"""
Hypergraph edge for the taskgraph.
"""
mutable struct TaskgraphEdge
    sources ::Vector{String}
    sinks   ::Vector{String}
    metadata::Dict{String,Any}
    """
        TaskgraphEdge(source, sink, metadata = Dict{String,Any}())

    Convenience function allowing construction of an taskgraph edge initialized
    with an empty metadata array.

    Argument `source` or `sink` can either be strings or vectors of strings.
    """
    function TaskgraphEdge(source, sink, metadata = Dict{String,Any}())
        sources = typeof(source)   <: Vector ? source : [source]
        sinks   = typeof(sink)     <: Vector ? sink   : [sink]
        return new(sources, sinks, metadata)
    end
end

getsources(t::TaskgraphEdge) = t.sources
getsinks(t::TaskgraphEdge)   = t.sinks

mutable struct Taskgraph
    name            ::String
    nodes           ::Dict{String, TaskgraphNode}
    edges           ::Vector{TaskgraphEdge}
    adjacency_out   ::Dict{String, Vector{TaskgraphEdge}}
    adjacency_in    ::Dict{String, Vector{TaskgraphEdge}}

    function Taskgraph(name, node_container, edge_container)
        # First - create the dictionary to store the nodes. Nodes can be
        # accessed via their name.
        nodes = Dict(n.name => n for n in node_container)
        # Initialize the adjacency lists with an entry for each node. Initialize
        # the values to empty arrays of edges so down-stream algortihms won't
        # have to check if an adjacency list exists for a node.
        edges = collect(edge_container)
        adjacency_out = Dict(name => TaskgraphEdge[] for name in keys(nodes))
        adjacency_in  = Dict(name => TaskgraphEdge[] for name in keys(nodes))
        # Iterate through all edges - grow adjacency lists correctly.
        for edge in edges
            for source in edge.sources
                push!(adjacency_out[source], edge)
            end
            for sink in edge.sinks
                push!(adjacency_in[sink], edge)
            end
        end
        # Return the data structure
        return new(
            name,
            nodes,
            edges,
            adjacency_out,
            adjacency_in,
        )
    end
end

function apply_transforms(tg, atc::AbstractTaskgraphConstructor)
    debug_print(:start, "Applying Transforms\n")
    # Get the transforms requested by the constructor.
    transforms = get_transforms(atc)
    for t in transforms
        if DEBUG
            debug_print(:substart, "Transform: ")
            debug_print(:none, string(t), "\n")
        end
        tg = t(tg)::Taskgraph
    end
    return tg
end

get_transforms(atc::AbstractTaskgraphConstructor) = ()

################################################################################
# METHODS FOR THE TASKGRAPH
################################################################################
# -- Some accessor methods.
getnodes(tg::Taskgraph) = values(tg.nodes)
getedges(tg::Taskgraph) = tg.edges
getnode(tg::Taskgraph, node::String) = tg.nodes[node]
getedge(tg::Taskgraph, i::Integer) = tg.edges[i]

# -- helpful query methods.
nodenames(tg::Taskgraph) = keys(tg.nodes)
num_nodes(tg::Taskgraph) = length(getnodes(tg))
num_edges(tg::Taskgraph) = length(getedges(tg))

"""
    add_node(tg::Taskgraph, task::TaskgraphNode)

Add a new node to the taskgraph. If a node with the same name already exists,
throw an error.
"""
function add_node(tg::Taskgraph, task::TaskgraphNode)
    if haskey(tg.nodes, task.name)
        error("Task ", task.name, " already exists in taskgraph.")
    end
    tg.nodes[task.name] = task
    # Create adjacency list entries for the new nodes
    tg.adjacency_out[task.name] = TaskgraphEdge[]
    tg.adjacency_in[task.name]  = TaskgraphEdge[]
    return nothing
end

"""
    add_edge(tg::Taskgraph, edge::TaskgraphEdge)

Add a new edge to the graph. No check is performed to ensure redundant edges
are not added.
"""
function add_edge(tg::Taskgraph, edge::TaskgraphEdge)
    # Update the edge array
    push!(tg.edges, edge)
    # Update the adjacency lists.
    for source in edge.sources
        push!(tg.adjacency_out[source], edge)
    end
    for sink in edge.sinks
        push!(tg.adjacency_in[sink], edge)
    end
    return nothing
end


# Methods for accessing the adjancy lists
"Return the edges for which the task is a source."
out_edges(tg::Taskgraph, task::String) = tg.adjacency_out[task]
"Return the edges for which the task is a source."
out_edges(tg::Taskgraph, task::TaskgraphNode) = out_edges(tg, task.name)
"Return the edges for which the task is a sink."
in_edges(tg::Taskgraph, task::String) = tg.adjacency_in[task]
"Return the edges for which the task is a sink."
in_edges(tg::Taskgraph, task::TaskgraphNode) = in_edges(tg, task.name)

# Checking methods
hasnode(tg::Taskgraph, node::String) = haskey(tg.nodes, node)

# Methods for accessing metadata
metadata(t::TaskgraphNode) = t.metadata
metadata(t::TaskgraphEdge) = t.metadata

# Methods for iterating through neighborhoods
function out_nodes(tg::Taskgraph, node)
    # Sink node iterators
    sink_name_iters = (e.sinks for e in out_edges(tg, node))
    # Flatten the sink iterators and get the distinct results.
    distinct_sink_names = distinct(Base.Iterators.flatten(sink_name_iters))
    # Finally, pipe this into a generator to return the actual node object.
    nodes = (getnode(tg, n) for n in distinct_sink_names)
    return nodes
end

end # module Taskgraphs
