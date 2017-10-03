#=
Taskgraph constructors will go here. If the number of constructors gets very
large - may want to think about moving the collection of constructors to
a subdirectory in the Taskgraphs folder.

Initially - there will be only one constructor that will take the sim-dump JSON
directly and import it almost verbatim into the Taskgraph data type.

From there - stages of processing will take place to compute link weights,
distance limits, etc.

Additionally, may include support for the modified JSON file that we've been
generating for Mapper1. However, this is low priority and not very likely since
working on the Taskgraph data structure directly is likely to be much more
convenient and will yield cleaner code.
=#
struct SimDumpConstructor <: AbstractTaskgraphConstructor
    file::String
end

#=
Question - how to handle loading of j
=#
function Taskgraph(c::SimDumpConstructor)
    # Get the file from the sim-dump constructor and JSON parse the file.
    f = open(c.file, "r")
    jsn = JSON.parse(f)::Dict{String,Any}
    close(f)
    # Pre-allocate array to hold the taskgraph nodes.
    nodes = [TaskgraphNode(k,v) for (k,v) in jsn]
    # Iterate through the dictionary again. Look at the "input_buffers" field
    # of each core to construct a link. Only need to look at the input field
    # to build the whole taskgraph.
    edges = TaskgraphEdge[]
    for (name,data) in jsn
        if haskey(data, "input_buffers")
            # Get all the input buffers, filter out all entries of "nothing"
            for input_buffer in filter(x -> x != nothing, data["input_buffers"])
                # Create a link from the writer core to the current core
                # referenced by "name". Use the whole buffer dict as metadata.
                metadata = input_buffer
                source   = input_buffer["writer_core"]::String
                sink     = name
                new_edge = TaskgraphEdge(source, sink, metadata)
                push!(edges, new_edge)
            end
        end
    end
    # Create the taskgraph
    return Taskgraph(nodes, edges)
end

#=
Want to make a set of generalized transforms that can be run on the post
parsed taskgraph to generate the task attribute requirements and link weights.

Options for how to procede:

1. Have specific algorithms implemented for each constructor type. Will be
    powerful but require a lot of code to be generated if we ever want
    more constructors.

2. Try to find general kernals that can be applied across many constructors
    and maybe even called multiple times with different parameters. Might
    be more complex to set up but more extensible? Maybe?

Will probably have to end up doing a bit of both.

DECISION: Transforms will likely be very dependant on the constructor, so to
a large extent will have to be implemented for each constructor type.
Fortunately, there shouldn't be too many distinct constructors.

Furthermore, there will be different run characteristics such as:
- doing a normal mapping with just weights for the links
- adding distance limits to the links
- performing task suitability

All of these may have a different subset of all the transforms needed to
run properly. Thus, it probably makes sense to implement the transforms
listed below for the SimDumpConstructor.

NOTE: While implementing these transforms, think if there is a convenient way
to spawn off common operations into kernel functions.

################################################################################
Transforms needed to get Mapper2 to the state of Mapper1:

0. Assign attributes needed to each node based off the type string.
1. Unpack the "attached_memory" field if there is one.
2. Annotate the links with weights and distance limits.
    - Think about if it makes sense to break apart having just pure weights
        and adding distnace limits as one of the options that can be chosen
        by the top level Map data structure.
=#
