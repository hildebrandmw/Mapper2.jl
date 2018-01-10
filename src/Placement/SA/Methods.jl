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

#=
NOTE: for the functions "map_cost" and "node_code", we do the funky schenanigans
with the "first" bool to make sure that "cost" is the correct return type
to make this code fast.

TODO: Think of a better way to make this code generic.
=#

map_cost(sa::SAStruct) = map_cost(architecture(sa), sa)
function map_cost(::Type{A}, sa::SAStruct) where {A <: AbstractArchitecture}
    cost = sum(edge_cost(A, sa, edge) for edge in eachindex(sa.edges))
    return cost
end

#@generated function node_cost(::Type{A}, sa::SAStruct, node) where { A<: AbstractArchitecture}
#    # Get the return type of "edge_cost(A, sa, edge)"
#    cost_type = Core.Inference.return_type(edge_cost, (A, sa, edgetype(sa)))
#    return quote
#        cost = zero($cost_type) 
#        n = sa.nodes[node]
#        for edge in n.out_edges
#            cost += edge_cost(A, sa, edge)
#        end
#        for edge in n.in_edges
#            cost += edge_cost(A, sa, edge)
#        end
#        return cost
#    end
#end

function node_cost(::Type{A}, sa::SAStruct, node) where {A <: AbstractArchitecture}
    # Get the node type from the SA Structure.
    n = sa.nodes[node]
    local cost
    first = true
    for edge in n.out_edges
        if first
            cost = edge_cost(A, sa, edge)
            first = false
        else
            cost += edge_cost(A, sa, edge)
        end
    end
    for edge in n.in_edges
        if first
            cost = edge_cost(A, sa, edge)
            first = false
        else
            cost += edge_cost(A, sa, edge)
        end
    end
    # If cost is not initialized, throw an error
    first && error()
    return cost
end
