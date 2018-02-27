################################################################################
# BFS Routines for building the distance look up table
################################################################################
function build_distance_table(architecture::TopLevel{A,D}) where {A,D}
    # The data type for the LUT
    dtype = UInt8
    # Pre-allocate a table of the right dimensions.
    dims = dim_max(addresses(architecture))
    # Replicate the dimensions once to get a 2D sized LUT.
    distance = Array{dtype}(dims..., dims...)
    # Get the neighbor table for finding adjacent components in the top level.
    neighbor_table = build_neighbor_table(architecture)

    @debug "Building Distance Table"
    # Run a BFS for each starting address
    @showprogress 1 for address in addresses(architecture)
        bfs!(distance, architecture, address, neighbor_table)
    end
    return distance
end

#=
Simple data structure for keeping track of costs associated with addresses
Gets put the the queue for the BFS.
=#
struct CostAddress{U,D}
    cost::U
    address::CartesianIndex{D}
end

function bfs!(distance::Array{U,N}, architecture::TopLevel{A,D},
              source::CartesianIndex{D}, neighbor_table) where {U,N,A,D}
    # Create a queue for visiting addresses.
    q = Queue(CostAddress{U,D})
    # Add the source addresses to the queue
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items and add the source to that set.
    queued_addresses = Set{CartesianIndex{D}}()
    push!(queued_addresses, source)
    # Begin BFS - iterate until the queue is empty.
    while !isempty(q)
        u = dequeue!(q)
        distance[source, u.address] = u.cost
        for v in neighbor_table[u.address]
            if v ∉ queued_addresses
                enqueue!(q, CostAddress(u.cost + one(U), v))
                push!(queued_addresses, v)
            end
        end
    end
    return nothing
end

function build_neighbor_table(architecture::TopLevel{A,D}) where {A,D}
    dims = Int64.(dim_max(addresses(architecture)))
    @debug "Building Neighbor Table"
    # Get the connected component dictionary
    cc = MapperCore.connected_components(architecture)
    # Create a big list of lists
    neighbor_table = Array{Vector{CartesianIndex{D}}}(dims)
    for (address, set) in cc
        neighbor_table[address] = collect(set)
    end
    return neighbor_table
end
