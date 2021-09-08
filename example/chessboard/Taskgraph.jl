################################################################################
# Taskgraph
################################################################################
abstract type TaskgraphColor end

struct AllGray end
struct OddEven end
struct Quarters end

color(::AllGray, args...) = Gray
color(::OddEven, i) = isodd(i) ? White : Black
color(::Quarters, i) = (White, Black, Gray, Gray)[mod(i, 4) + 1]

function taskgraph(ntasks, nedges, shade = AllGray())
    tasks = [
        TaskgraphNode(string(i); metadata = Dict("color" => color(shade, i))) for
        i in 1:ntasks
    ]

    edges = map(1:nedges) do _
        source = rand(1:ntasks)
        dest = rand(1:ntasks)

        return TaskgraphEdge(string(source), string(dest))
    end

    return Taskgraph("taskgraph", tasks, edges)
end

function linegraph(ntasks, shade = AllGray())
    tasks = [
        TaskgraphNode(string(i); metadata = Dict("color" => color(shade, i))) for
        i in 1:ntasks
    ]

    edges = [TaskgraphEdge(string(i), string(i + 1)) for i in 1:(ntasks - 1)]

    return Taskgraph("taskgraph", tasks, edges)
end
