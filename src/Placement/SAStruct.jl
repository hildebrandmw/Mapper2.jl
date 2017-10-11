# Work out a way of doing "representatives" for each 

#=
The structure that will be used for placement in the new taskgraph.

Will take a Map structure and spawn off its own specialized structure.
=#
"""
Fields required by specialized SANode types:
* address::Address{D} where D is the dimension of the architecture.
* component_index <: Integer
* out_links::Vector{Int64}
* in_links::Vector{Int64}
"""
abstract type AbstractSANode end

"""
Fields required by specialized SANode types:
* sources::Vector{Int64}
* sinks::Vector{Int64}
* cost::Float64
"""
abstract type AbstractSAEdge end

"""
Paramters:

* `A` - The Architecture Type
* `U` - Element type for the distance calculation LUT.
* `D` - The number of dimensions for the placement.
* `D2`- Twice `D`. (still haven't figured out how to make julia to arithmetic
                    with type parameters)
* `N` - Task node type.
* `L` - Link node type.
"""
mutable struct SAStruct{A,U,D,D2,N <: AbstractSANode,L <: AbstractSAEdge}
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
    maptables::Vector{Array{Vector{UInt8}}}
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
mutable struct BasicSANode{D} <: AbstractSANode
    address         ::Address{D}
    component_index ::Int64
    out_edges       ::Vector{Int64}
    in_edges        ::Vector{Int64}
end
# Fallback constructor for task nodes.
function build_sa_node(::AbstractArchitecture, n::TaskgraphNode, D)
    return BasicSANode(Address(D), 0, Int64[], Int64[])
end

struct BasicSAEdge <: AbstractSAEdge
    sources::Vector{Int64}
    sinks  ::Vector{Int64}
end

function build_sa_edge(::AbstractArchitecture, edge::TaskgraphEdge, node_dict)
    # Build up adjacency lists.
    # Sources in the task-graphs are strings so we can just use the
    # node-dictionary to convert them into integers.
    sources = [node_dict[s] for s in edge.sources]
    sinks   = [node_dict[s] for s in edge.sinks]
    return BasicSAEdge(sources, sinks)
end


################################################################################
# Constructor for the SA Structure
################################################################################

function SAStruct(m::Map{A,D}) where {A,D}
    architecture = m.architecture
    taskgraph    = m.taskgraph
    # First step - create the component_table.
    component_table = build_component_table(architecture)

    # Next step, build the SA Taskgraph
    sa_nodes = [build_sa_node(A(), n, D) for n in nodes(taskgraph)]
    # Build dictionary to map node names to indices
    node_dict = Dict(n.name => i for (i,n) in enumerate(nodes(taskgraph)))
    # Build the basic links
    sa_edges = [build_sa_edge(A(), n, node_dict) for n in edges(taskgraph)]
    # Reverse populate the the nodes so they track their edges.
    record_edges!(sa_nodes, sa_edges)

    #=
    Need to do the following:

    1. Get node equivalence classes
    2. Get get component equivalence classes
    3. Profit
    =#
    normal_node_classes, special_node_classes = get_node_equivalence_classes(
            A(),
            taskgraph
        )
    
    return sa_nodes, sa_edges
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

function record_edges!(nodes, edges)
    # Reverse populate the the nodes so they track their edges.
    for (i,edge) in enumerate(edges)
        for j in edge.sources
            push!(nodes[j].out_edges, i)
        end
        for j in edge.sinks
            push!(nodes[j].in_edges, i)
        end
    end
    return nothing
end

