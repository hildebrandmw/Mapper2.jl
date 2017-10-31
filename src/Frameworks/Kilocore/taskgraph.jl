# Use JSON to parse the simulation dumps
using JSON
# Use GZip to allow the JSON files to be compressed. Saves quit a bit of
# space.
using GZip
#=
Taskgraph constructors will go here. If the number of constructors gets very
large - may want to think about moving the collection of constructors to a subdirectory in the Taskgraphs folder.

Initially - there will be only one constructor that will take the sim-dump JSON
directly and import it almost verbatim into the Taskgraph data type.

From there - stages of processing will take place to compute link weights,
distance limits, etc.

Additionally, may include support for the modified JSON file that we've been
generating for Mapper1. However, this is low priority and not very likely since
working on the Taskgraph data structure directly is likely to be much more
convenient and will yield cleaner code.
=#

################################################################################
# Taskgraph Constructors used by the Kilocore framework.
################################################################################
struct SimDumpConstructor <: AbstractTaskgraphConstructor
    name::String
    file::String
    function SimDumpConstructor(appname)
        # Just copy the app name for the "name" portion of the constructor
        # Split it on any "." points and take the first argument.
        name = split(appname, ".")[1]
        # Check if appname ends in ".json.gz". If not, fix that
        appname = split(appname, ".")[1] * ".json.gz"
        # Append the sim dump file path to the beginning.
        file = joinpath(PKGDIR, "sim-dumps", appname)
        return new(name, file)
    end
end

function Taskgraph(c::SimDumpConstructor)
    # Get the file from the sim-dump constructor and JSON parse the file.
    f = GZip.open(c.file, "r")
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
    return Taskgraph(c.name, nodes, edges)
end

################################################################################
# Custom Taskgraph Transforms.
################################################################################

"""
    get_transforms(sdc::SimDumpConstructor)

Return the list of transforms needed by the `SimDumpConstructor`.
"""
function get_transforms(sdc::SimDumpConstructor)
    transform_tuple = (
        t_unpack_attached_memories,
        t_unpack_type_strings,
        t_confirm_and_sort_attributes,
        t_assign_link_weights,
    )
    return transform_tuple
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
################################################################################

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
    # Record a set of unpacked memories so a memory that has a node in
    # the graph isn't accidentally added again.
    memories_unpacked = Set{String}()
    for node in nodes(tg)
        # Check if this has the Get_Type_String() == memory property. If so,
        # we need to add an output link to its host processor.
        if get(node.metadata, "Get_Type_String()", "") == "memory"
            haskey(node.metadata, "output_buffers") || continue
            # Get all the input buffers, filter out all entries of "nothing"
            for output_buffer in filter(x -> x != nothing, node.metadata["output_buffers"])
                # Create a link from the writer core to the current core
                # referenced by "name". Use the whole buffer dict as metadata.
                metadata = output_buffer
                source   = node.name
                sink     = output_buffer["reader_core"]::String
                add_edge(tg, TaskgraphEdge(source, sink, metadata))
                edges_added += 1
            end
        elseif haskey(node.metadata, "attached_memory")
            # Get the memory node - check if it already
            memory = node.metadata["attached_memory"]::String
            if !hasnode(tg, memory)
                # Create metadata with the "Get_Type_String()" attribute
                metadata = Dict("Get_Type_String()" => "memory")
                # Create a memory node for the memory
                add_node(tg, TaskgraphNode(memory, metadata))
                push!(memories_unpacked, memory)
                nodes_added += 1
            end
            # Check if this memory was an unpacked memory. If so, create a link.
            # Otherwise, a link will already exist.
            if memory in memories_unpacked
                # Create links
                add_edge(tg, TaskgraphEdge(node.name, memory))
                add_edge(tg, TaskgraphEdge(memory, node.name))
                edges_added += 2
            end
            # Delete the attached memory field from the node to make the transform
            # safe to run multiple times.
            delete!(node.metadata, "attached_memory")
        end
    end
    if DEBUG
        print_with_color(:green, "Nodes added: ", nodes_added, "\n")
        print_with_color(:green, "Edges added: ", edges_added, "\n")
    end
    return tg
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
        # Check if any of the sources or sinks of this edge is an input.
        # if so - assign a small weight to that link
        for nodename in chain(edge.sources, edge.sinks)
            if oneofin(tg.nodes[nodename].metadata["required_attributes"], 
                       ("input_handler", "output_handler"))
                edge.metadata["weight"] = 1/8
            end
        end
    end

    return tg
end

"""
    t_confirm_and_sort_attributes(tg::Taskgraph)

Confirm that each node in the taskgraph has a non-empty "required_attributes"
field. Sort that field for consistency.
"""
function t_confirm_and_sort_attributes(tg::Taskgraph)
    badnodes = TaskgraphNode[]
    for node in nodes(tg)
        #=
        Ensure that each node has a "required_attributes" field. If not, add
        it to a list to help with debugging.
        =#
        if haskey(node.metadata, "required_attributes")
            sort!(node.metadata["required_attributes"])
        else
            push!(badnodes, node)
        end
    end
    if length(badnodes) > 0
        print_with_color(:red, "Found ", length(badnodes), " nodes without a",
                         " \"required_attributes\" metadata.")
        for node in badnodes
            println(node)
        end
        error()
    end
    return tg
end
