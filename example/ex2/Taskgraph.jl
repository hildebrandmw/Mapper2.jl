const node_names = ["task$i" for i in 1:27]
const edge_tuples = [("task$i", "task$(i+1)") for i in 1:26]

function make_taskgraph()
    name = "test_taskgraph"
    nodes = TaskgraphNode[]
    edges = TaskgraphEdge[]
    t = Taskgraph(name, nodes, edges)
    for n in node_names
        add_node(t, TaskgraphNode(n))
    end
    for (src, snk) in edge_tuples
        add_edge(t, TaskgraphEdge(src, snk))
    end
    return t
end
