module Example3

# Import the Mapper package.
using Mapper2

# Much of the exact behavior of the Mapper is controlled by parameterizing the
# TopLevel and Map types with a subtype of AbstractArchitecture.
#
# This declarations allows us to extend various methods of placement and routing,
# should we want.
#
# If we don't extend those, default behavior will be used.
struct EX3 <: AbstractArchitecture end

# A tutorial on how to model a simple architecture.
include("Architecture.jl")

# Building a taskgraph for this simple architecture.
include("Taskgraph.jl")

# With the Architecture and Taskgraph defined, creating a Map is easy!.
function make_map(;width = 4, height = 4, ntasks = 10, nedges = 20)
    arch = build_arch(width, height)
    taskgraph = make_taskgraph(ntasks, nedges)

    return NewMap(arch, taskgraph)
end

end
