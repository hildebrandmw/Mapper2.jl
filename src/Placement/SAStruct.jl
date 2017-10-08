#=
The structure that will be used for placement in the new taskgraph.

Will take a Map structure and spawn off its own specialized structure.
=#
"""
Paramters:

* `A` - The Architecture Type
* `U` - Element type for the distance calculation LUT.
* `D` - The number of dimensions for the placement.
* `D2`- Twice `D`.
* `N` - Task node type.
* `L` - Link node type.
"""
mutable struct SAStruct{A,U,D,D2,N,L}
    """
    Hold an empty reference to the architecure type to make some function
    dispatches a little easier.
    """
    architecture::A
    dimension::D
    nodetype::N
    linktype::L

    "Specialized node type."
    nodes::Vector{N}
    "Specialized link type."
    links::Vector{L}
    #= Look up tables for doing placement.  =#
    #=
    TODO: Think if making a special "maptables" class makes sense. Might be
        more testable.
    =#
    """
    The node class maps nodes in the `nodes` vector to their category. This is
    used to reduce necessary size of the `maptable`.

    - Node classes with a positive ID will be moved using the
         standard move generator.
    - Node classes with a negative ID will be moved using the special move
        table where valid destinations are pre-calculated.
    """
    nodeclass::Vector{Int64}
    """
    This is a look-up table to determine which mapable component at a given
    address can support a certain taskclass.

    The flow will look like this:

    1. An index for a task will be chosen.
    2. That index will be used to look up an integer nodeclass.
    3. That node class will then be used to index into the maptables do
        determine if a node can be mapped to that component.

        The order of components at an address will be determined at structure
        creation time.
    """
    maptables::Vector{Array{BitArray{1}, D}}
    """
    The special map tables where a set of valid destination addresses for a node
    class are pre-computed and a valid destination address is chosen for move
    generation.
    """
    special_maptables::Vector{Vector{Address}}
    """
    Distance look-up table. This is twice the size of the the address dimension
    to allow distances to be calculated from any source address to any
    destination address.
    """
    distance::Array{U,D2}
    #=
    Component tables for tracking local component references to the global
    reference in the Map data type
    =#
    component_table::Array{Vector{String}, D}
end

################################################################################
# Templates for the basic task and link types
################################################################################

# TODO: Think about how this has to get dispatched depending on taskgraphs AND
# architectures.
"""
Fields required by specialized SANode types:
* address::Address{D} where D is the dimension of the architecture.
* component_index <: Integer
* out_links::Vector{Int64}
* in_links::Vector{Int64}
"""
abstract type AbstractSANode end
mutable struct BasicSANode{D} <: AbstractSANode
    address         ::Address{D}
    component_index ::Int64
    out_links       ::Vector{Int64}
    in_links        ::Vector{Int64}
end
SANodeType(::AbstractArchitecture) = BasicSANode

"""
Fields required by specialized SANode types:
* sources::Vector{Int64}
* sinks::Vector{Int64}
* cost::Float64
"""
abstract type AbstractSALink end
mutable struct BasicSALink <: AbstractSALink
    sources::Vector{Int64}
    sinks  ::Vector{Int64}
    cost   ::Float
end
SALinkType(::AbstractArchitecture) = BasicSALink

function SAStruct(m::Map{A,D}) where {A,D}
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # First step - create the component_table.
    component_table = build_component_table(architecture)
    # Next step - build two representative lists. One for normal tasks,
    # one for special tasks.
end

function build_component_table(tl::TopLevel{A,D}) where {A,D}
    # Get the dimensions of the addresses to build the array that is going to
    # hold the component table. Get the inside tuple for creation.
    table_dims = address_extrema(addresses(tl)).addr
    println(table_dims)
    component_table = Array{Vector{String}}(table_dims...)
    # Initialize every entry to an empty vector of strings.
    # Could do this using the "fill" function - but that makes every entry
    # it's own unique array, which isn't exactly what we want.
    for i in eachindex(component_table)
        component_table[i] = String[]
    end
    # Start iterating through all components at each address. Call is "ismappable"
    # function on each. If the component is mappable, add it's name to the
    # string vector at the current address.
    for (address, component) in tl.children
        for (child, name) in walk_children(component)
            # If the component is considered mappable by the current architecture,
            # add the name of the component to the current list.
            if ismappable(A(), child)
                push!(component_table[address], name)
            end
        end
    end
    return component_table
end
