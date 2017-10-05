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
        by the top level Map data structure.  =#

function c_unpack_attached_memories()
    return TaskgraphTransform(
        "unpack_attached_memories",
        Set{TaskgraphTransform}(),
        t_unpack_attached_memories,
     )
end
"""
    t_unpack_attached_memories(tg::Taskgraph)

Iterates through all nodes in a taskgraph. If it finds a node with a metadata
field of "attached_memory", will create a new node for that attached memory and
a bidirectional link from the memory to the node.

Also removes the "attached_memory" field from the node so it should be safe to
run multiple times.
"""
function t_unpack_attached_memories(tg::Taskgraph)
    nodes_added = 0
    edges_added = 0
    for node in nodes(tg)
        haskey(node.metadata, "attached_memory") || continue
        # Get the memory node - check if it already
        memory = node.metadata["attached_memory"]::String
        if !hasnode(tg, memory)
            # Create metadata with the "Get_Type_String()" attribute
            metadata = Dict("Get_Type_String()" => "memory")
            # Create a memory node for the memory
            add_node(tg, TaskgraphNode(memory, metadata))
            nodes_added += 1
        end
        # TODO: Get this to work when there are both attached memories and
        # separate tasks for memories.

        # Create links
        add_edge(tg, TaskgraphEdge(node.name, memory))
        add_edge(tg, TaskgraphEdge(memory, node.name))
        edges_added += 2
        # Delete the attached memory field from the node to make the transform
        # safe to run multiple times.
        delete!(node.metadata, "attached_memory")
    end
    if DEBUG
        print_with_color(:green, "Nodes added: ", nodes_added, "\n")
        print_with_color(:green, "Edges added: ", edges_added, "\n")
    end
    return tg
end

function c_unpack_type_strings()
    return TaskgraphTransform(
        "unpack_type_strings",
        Set([c_unpack_attached_memories()]),
        t_unpack_type_strings,
     )
end

"""
    t_unpack_type_strings(tg::Taskgraph)

Assign required attributes to each task node based on the "Get_Type_String()"
field of the JSON dump. No effect if the "Get_Type_String()" field does not
exist in a node's metadata.

Deletes the "Get_Type_String()" entry from the metadata dictionary after running
so is safe to run multiple times.
"""
function t_unpack_type_strings(tg::Taskgraph)
    for node in nodes(tg)
        # Quick check to make sure this field exists
        haskey(node.metadata, "Get_Type_String()") || continue
        type_string = node.metadata["Get_Type_String()"]
        if type_string == "memory"
            # Check the number of neighbors
            neighbors = length(tg.adjacency_out[node.name])
            if neighbors == 1
                push_to_dict(node.metadata, "required_attributes", "memory_1port")
            elseif neighbors == 2
                push_to_dict(node.metadata, "required_attributes", "memory_2port")
            else
                error("Memory module ", node.name, " has ", neighbors,
                      " neighbors. Expecred 1 or 2.")
            end
            # Iterate through each out node - attach the "memory_processor"
            # attribute to this node.
            # TODO: Make this more robust to make sure destination is actually a
            # processor
            for out_node in out_nodes(tg, node)
                push_to_dict(out_node.metadata, "required_attributes",
                             "memory_processor")
            end
        else
            push_to_dict(node.metadata, "required_attributes", type_string)
        end
        # Delete the "Get_Type_String()" field to make this function safe to run
        # multiple times.
        delete!(node.metadata, "Get_Type_String()")
    end
    return tg
end

function c_assign_link_weight()
    return TaskgraphTransform(
        "assign_link_weight",
        Set([c_unpack_type_strings()]),
        t_assign_link_weights,
     )
end

"""
    t_assign_link_weights(tg::Taskgraph)

Assign weights to each link in the taskgraph by comparing the number of writes
for a link to the average number of writes across all links.

If "num_writes" is not defined for a link, a default value is used.
"""
function t_assign_link_weights(tg::Taskgraph)
    # First - get the average number of writes over all links.
    # Accumulator for the total number of writes.
    total_writes = 0::Int64
    # Some edges might not have a number of writes field (such as the unpacked
    # memories). This variable will track the number of edges that have this
    # field and thus contribute to the total number of writes
    contributing_edges = 0
    for edge in edges(tg)
        haskey(edge.metadata, "num_writes") || continue
        total_writes += edge.metadata["num_writes"]::Int64
        contributing_edges += 1
    end
    average_writes = total_writes / contributing_edges
    # Assign link weights by comparing to the average. Round to three binary
    # digits.
    base            = 2
    round_digits    = 3
    default_weight  = 1.0
    # Assign weights.
    for edge in edges(tg)
        if haskey(edge.metadata, "num_writes")
            ratio = edge.metadata["num_writes"] / average_writes::Float64
            weight = max(1, round(ratio, round_digits, base))
            edge.metadata["weight"] = weight
        else
            edge.metadata["weight"] = default_weight
        end
    end
    return tg
end
