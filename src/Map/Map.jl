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

* `D` - The number of dimensions in the architecture. (will usually be 2 or 3).
"""
mutable struct Map{D}
    architecture::TopLevel{D}
    #=
    taskgraph
    mapping

    # Options
    # TODO: Need to think about how to do quality control on all the metadata
    # options that show up in this structure.

    """
    Options to control all aspects of the mapping process. Data stored in the
    options dictionary should usually be more dictionaries.

    For example, there can be a dictionary for placement, dictionary for routing,
    dictionaries controlling what will be dumped into the final file etc.        
    
    """
    options::Dict{Symbol,Any}
    =#
end
