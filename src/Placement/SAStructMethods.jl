#=
Authors
    Mark Hildebrand

A collection of methods for interacting with the SAStruct.
=#

"""
    assign(sa::SAStruct, node, component, address)

Assigns the `node` index to the given `address` and `component` index at that
address.
"""
function assign(sa::SAStruct, node, component, address)
    # Update the grid
    sa.grid[component, address] = node
    sa.nodes[node].component = component
    sa.nodes[node].address = address
    return nothing
end

"""
    move(sa::SAStruct, node, component, address)

Move `node` to the given `component` and `address`.
"""
function move(sa::SAStruct, node, component::Integer, address::Address)
    # Clear out the present location of the node.
    sa.grid[sa.nodes[node].component, sa.nodes[node].address] = 0
    # Assign it a new location.
    assign(sa, node, component, address)
    return nothing
end

"""
    swap(sa::SAStruct, node1, node2)

Swap two nodes in the placement structure.   
"""
function swap(sa::SAStruct, node1, node2)
    # Get references to these objects to make life easier.
    n1 = sa.nodes[node1]
    n2 = sa.nodes[node2]
    # Swap address/component assignments
    n1.address, n2.address = n2.address, n1.address
    n1.component, n2.component = n2.component, n1.component
    # Swap grid.
    sa.grid[n1.component, n1.address] = node1
    sa.grid[n2.component, n2.address] = node2
    return nothing
end

################################################################################
# DEFAULT METRIC FUNCTIONS
################################################################################
function edge_cost(::Type{A}, sa::SAStruct, edge) where {A <: AbstractArchitecture}
    cost = 0
    for src in sa.edges[edge].sources, snk in sa.edges[edge].sinks
        # Get the source and sink addresses
        src_address = sa.nodes[src].address
        snk_address = sa.nodes[snk].address
        cost += Int64(sa.distance[src_address, snk_address])
    end
    return cost
end

function map_cost(::Type{A}, sa::SAStruct) where {A <: AbstractArchitecture}
    cost = 0
    for edge in eachindex(sa.edges)
        cost += edge_cost(A, sa, edge)
    end
    return cost
end

function node_cost(::Type{A}, sa::SAStruct, node) where {A <: AbstractArchitecture}
    # Get the node type from the SA Structure.
    n = sa.nodes[node]
    cost = 0
    for edge in n.out_edges
        cost += edge_cost(A, sa, edge)
    end
    for edge in n.in_edges
        cost += edge_cost(A, sa, edge)
    end
    return cost
end
