#=
The Map is going to be the top level data structure - containing:

1. The Architecture model
2. The Task-Graph
3. Mapping information between the taskgraph and architecture
4. All miscelaneous data types needed to spawn off the specialized datastructures
    needed for placement, routing, etc.

The big idea in this project is to make selection of algorithms, metrics, and
algorithm parameters be done via Julia's type dispatch system. That is, different
algorithms/parameters will be selected by storing a type corresponding to those
parameters in the top level data structure.

When lower level routines such as the simulated annealing placer are launched,
these types can be unpacked to dispatch to the correct functions.

Use of the function-wrapper technique should probably be used to ensure that
when the kernel functions are called - everything is type stable.
=#

"""
Top level data structure. Summary of parameters:

* `A` - The architecture type used for the mapping.
* `D` - The number of dimensions in the architecture (will usually be 2 or 3).
"""
mutable struct Map{A,D}
    """
    The underlying architecture to which the taskgraph is going to be mapped.
    """
    architecture::TopLevel{A,D}
    """
    The application to be mapped to the architecture.
    """
    taskgraph   ::Taskgraph
    """
    Options for dispatching and parameterizing placement and routing functions.
    """
    options::Dict{Symbol, Any}
    #=
    mapping
    =#
end

function testmap()
    options = Dict{Symbol, Any}()
    arch = build_asap4()
    sdc  = SimDumpConstructor("alexnet", "alexnet-5-multiport-finetuned.json")
    tg   = apply_transforms(Taskgraph(sdc), sdc)
    return Map(arch, tg, options)
end








# ph
