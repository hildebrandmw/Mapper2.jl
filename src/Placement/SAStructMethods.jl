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
    # Make sure the location is empty - this function should be called rarely
    # so this overhead is okay.
    @assert sa.grid[component, address] == 0
    # Update the grid
    sa.grid[component, address] = node
    sa.nodes[node].component = component
    sa.nodes[node].address = address
    return nothing
end


