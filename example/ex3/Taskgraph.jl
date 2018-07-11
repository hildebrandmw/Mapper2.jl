# We keep generating taskgraphs super simple - just generate a random graph.
function make_taskgraph(ntasks, nedges)
    tasks = [TaskgraphNode(string(i)) for i in 1:ntasks]   

    # Randomly create edges.
    #
    # Since the Mapper supports multiple edges from a source to destination, we
    # don't have to worry about checking if an edge already exists.
    edges = map(1:nedges) do _
        source = rand(1:ntasks)
        dest = rand(1:ntasks)

        return TaskgraphEdge(string(source), string(dest))
    end

    return Taskgraph("taskgraph", tasks, edges)
end
