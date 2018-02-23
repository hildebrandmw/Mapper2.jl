@testset "Testing Taskgraphs" begin
    # Test some random stuff
    @test_throws TypeError Taskgraph("test", TaskgraphEdge[], TaskgraphEdge[])
    @test_throws TypeError Taskgraph("test", TaskgraphNode[], TaskgraphNode[])

    # Create the taskgraph provided by the example
    t = Example2.make_taskgraph()

    # Collet all the nodes and edges before hand and create the taskgraph all
    # at onces
    name = t.name
    nodes = [TaskgraphNode(n) for n in Example2.node_names]
    edges = [TaskgraphEdge(a,b) for (a,b) in Example2.edge_tuples]
    
    q = Taskgraph(name, nodes, edges)

    # start asking questions about the taskgraph
    @test sort(collect(nodenames(t))) == sort(collect(nodenames(q)))
    @test num_nodes(t) == num_nodes(q)
    @test num_edges(t) == num_edges(q)

    for nn in nodenames(t)
        @test hasnode(q, nn)
        # Get the two nodes
        a = getnode(t, nn)
        b = getnode(q, nn)
        @test length(out_edges(t,a)) == length(out_edges(q,b))
        @test length(in_edges(t,a)) == length(in_edges(q,b))
    end

    for nn in nodenames(t)
        a = out_nodes(t, nn)
        b = out_nodes(q, nn)
        # Get the names of these nodes
        a_names = [i.name for i in a]
        b_names = [i.name for i in b]

        @test sort(a_names) == sort(b_names)
    end

    # test some throwing of errors if we try to add a task that already exists
    @test_throws Exception add_edge(t, TaskgraphNode("task1"))
end
