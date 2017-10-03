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

abstract type AbstractTaskgraphType end
# Type for choosing the constructor.
abstract type AbstractTaskgraphConstructor end
"""
Nodes of the taskgraph.
"""
struct TaskgraphNode <: AbstractTaskgraphType
    name    ::String,
    metadata::Dict{String,Any}
end

"""
Hypergraph edge for the taskgraph.
"""
struct TaskgraphEdge <: AbstractTaskgraphType
    sources ::Vector{String}
    sinks   ::Vector{String}
    metadata::Dict{String,Any}
end

struct Taskgraph <: AbstractTaskgraphType
    nodes::Dict{String, TaskgraphNode}
    edges::Vector{TaskgraphEdge}
    adjacency_out::Dict{String, Vector{TaskgraphEdge}}
    adjacency_in ::Dict{String, Vector{TaskgraphEdge}}
    function Taskgraph(node_container, edge_container)
        # First - create the dictionary to store the nodes. Nodes can be
        # accessed via their name.
        nodes = Dict(n.name => n for n in nodes)
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
            nodes,
            edges,
            adjacency_out,
            adjacency_in,
        )
    end
end

################################################################################
# METHODS FOR THE TASKGRAPH
################################################################################

# Iterator interfaces for nodes. Can easily just grab an itertor over the node
# data types in the nodes dictionary.
"""
    nodes(tg::Taskgraph)

Return an itertor to uniquely visit each node of the taskgraph.
"""
nodes(tg::Taskgraph) = values(tg.nodes)

"""
    edges(tg::Taskgraph)

Return an iterator to uniqely visit each edge of the taskgraph.
"""
edges(tg::Taskgraph) = tg.edges

# Methods for accessing the adjancy lists
"Return the edges for which the task is a source."
out_edges(tg::Taskgraph, task::String) = tg.adjacency_out[task]
"Return the edges for which the task is a source."
out_edges(tg::Taskgraph, task::TaskgraphNode) = out_edges(tg, task.name)
"Return the edges for which the task is a sink."
in_edges(tg::Taskgraph, task::String) = tg.adjacency_in[task]
"Return the edges for which the task is a sink."
in_edges(tg::Taskgraph, task::TaskgraphNode) = in_edges(tg, task.name)


# Methods for accessing metadata - might not necessarily be useful.
metadata(t::TaskgraphNode) = t.metadata
metadata(t::TaskgraphEdge) = t.metadata
# ph
