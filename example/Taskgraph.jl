function make_taskgraph()
    name = "test_taskgraph"
    nodes = make_nodes()
    edges = make_edges()
    return Taskgraph(name, nodes, edges)
end

const input_node_names = ("input1", "input2")
const output_node_names = ("output1", "output2")
# Just have 6 general task nodes so the 8 general primites are underutilized.
const general_node_names = Tuple("task$i" for i in 1:6)

"""
    make_nodes()

Make a basic collection of input, output, and general nodes.
"""
function make_nodes()
    # input nodes. 
    input_metadata  = Dict("task" => "input")
    input_nodes = [TaskgraphNode(n, input_metadata) for n in input_node_names]
    # output nodes
    output_metadata  = Dict("task" => "output")
    output_nodes = [TaskgraphNode(n, output_metadata) for n in output_node_names]
    # general nodes
    general_metadata = Dict("task" => "general")
    general_nodes = [TaskgraphNode(n, general_metadata) for n in general_node_names]
    return vcat(input_nodes, output_nodes, general_nodes)
end

function make_edges()
    # The following tuple is a collection: (source_task, sink_task, class)
    # Class can be one of: {A,B,all}
    edges = [("input1","task1","A"),
             ("input2","task1","B"),
             ("task1","task2","B"),
             ("task2","task3","B"),
             ("task3","task4","B"),
             ("task4","task5","B"),
             ("task5","task6","B"),
             ("task1","task6","A"),
             ("task2","output1","A"),
             ("task6","output2","B"),
            ]

    return [TaskgraphEdge(a[1],a[2],Dict("class" => a[3])) for a in edges]
end
