################################################################################
# Abstract Types for Placement
################################################################################
abstract type PlacementNode end
abstract type PlacementChannel end
abstract type PlacementAddressData end


@doc """
Fields required by specialized SANode types:
* `address::Address{D}` where `D` is the dimension of the architecture.
* `component_index<:Integer`
* `out_links::Vector{Int64}`
* `in_links::Vector{Int64}`
""" PlacementNode

@doc """
Fields required by specialized SANode types:
* `sources::Vector{Int64}`
* `sinks::Vector{Int64}`
""" PlacementChannel

@doc """
Container allowing specific data to be associated with addresses in the
SAStruct. Useful for processor specific mappings such as core frequency or
leakage.
""" PlacementAddressData

@doc """
Default mapping doesn't use address specific data for its mapping objective.
The placeholder is just this empty type.
""" EmptyAddressData

################################################################################
# SA Struct
################################################################################


const Maptable{D} = Vector{Array{Vector{UInt8},D}}
"""
    struct SAStruct{A,U,D,D2,D1,N,L,T}

Data structure specialized for Simulated Annealing placement.

# Constructor
    SAStruct(Map::{A,D})

# Paramters

* `A` - The Architecture Type
* `U` - Element type for the distance calculation LUT.
* `D` - The dimension of the underlying architecture.
* `D2`- Twice `D`. (still haven't figured out how to make julia to arithmetic
                    with type parameters)
* `D1` - `D + 1`.
* `N <: PlacementNode` - Task node type.
* `L <: PlacementChannel` - Edge node type.
* `T <: PlacementAddressData`` - The AddressData type.

# Fields
* `nodes::Vector{N}` - Taskgraph Nodes specialized for placement.
* `edges::Vector{L}` - Taskgraph Edges specialized for placement.
* `nodeclass::Vector{Int64}` - Maps Taskgraph Nodes to their equivalence
    classes for placement. Positive value indicates use of the standard move
    generator while negative values indicate the special move generator.
* `maptables::Vector{Array{Vector{UInt8},D}}}` - Indicates which primitive at
    `address` a tasknode of equivalence class `i` can be mapped to.

    Accessed using `maptables[i][address]`. Returned indicies are the indicies
    or primitives that the task can be mapped to.
* `special_maptables::Vector{Array{Vector{UInt8,D}}} - Same as `maptables` but
    for special tasks.
* `special_addresstables::Vector{Vector{Address{D}}}` - Used to determine the
    addresses that a special tasknode of equivalence class `i` can occupy.

    Accessed using `special_addresstables[i]`. The tasknode can be mapped to
    at least one component at each address of the returned vector.
* `distance::Array{U,D2}` - Distance look up table from address `a` to address
    `b`. Precomputed using graph searches on the original architecture.
* `grid::Array{Int64,D1}` - Mapping from address `a`, component `i` to the
    tasknode index mapped to that location.

    Accessed via `grid[i,a]`. Returns `0` is no task is mapped to the component.
* `address_data::T` - Custom address specific datatype for implementing custom
    objective functions.
* `component_table::Array{Vector{ComponentPath},D}` - Mapping from the `SAStruct`
    to the parent `Map` type.
* `task_table::Dict{String,Int64}` - Mapping from the `SAStruct` to the parent
    `Map` type.
"""
struct SAStruct{A,U,D,D2,D1,N <: PlacementNode,L <: PlacementChannel,
                        T <: PlacementAddressData}
    nodes                   ::Vector{N}
    edges                   ::Vector{L}
    nodeclass               ::Vector{Int64}
    maptables               ::Maptable{D}
    special_maptables       ::Maptable{D}
    special_addresstables   ::Vector{Vector{Address{D}}}
    distance                ::Array{U,D2}
    grid                    ::Array{Int64, D1}
    address_data            ::T
    #=
    Component tables for tracking local component references to the global
    reference in the Map data type
    =#
    component_table ::Array{Vector{ComponentPath}, D}
    task_table      ::Dict{String,Int64}
end

# Convenience decoding methods - this is kinda gross.
dimension(::SAStruct{A,U,D})  where {A,U,D} = D
architecture(::SAStruct{A})   where {A} = A
nodetype(s::SAStruct) = typeof(s.nodes)
edgetype(s::SAStruct) = typeof(s.edges)
distancetype(::SAStruct{A,U}) where {A,U} = U

################################################################################
# Basis SA Node
################################################################################

mutable struct BasicPlaceNode{D} <: PlacementNode
    address  ::Address{D}
    component::Int64
    out_edges::Vector{Int64}
    in_edges ::Vector{Int64}
end

function build_node(::Type{T}, n::TaskgraphNode, D) where {T <: AbstractArchitecture}
    return BasicPlaceNode(Address{D}(), 0, Int64[], Int64[])
end

@doc """
    build_node(::Type{A}, n::TaskgraphNode, D::Integer)

Construct an `PlacementNode` for the given taskgraph node and architecture `A`
with dimension `D`.

Must initialize the required fields to their default values:
- `address = Address{D}()`
- `component = 0`
- `out_edges = Int[]`
- `in_edges  = Int[]`

Other additional fields left for your to implement as needed.
""" build_node

################################################################################
# Basis SA Edge
################################################################################

struct BasicPlaceChannel <: PlacementChannel
    sources::Int64
    sinks  ::Int64
end

function build_channel(::Type{T}, edge::TaskgraphEdge, node_dict) where {T <: AbstractArchitecture}
    # Build up adjacency lists.
    # Sources in the task-graphs are strings so we need to use the
    # node-dictionary to convert them into integers.
    if length(edge.sources) > 1
        error("Multi source nets are not implemented yet")
    end
    if length(edge.sinks) > 1
        error("Multi sink nets are not implemented yet")
    end
    sources  = node_dict[first(edge.sources)]
    sinks    = node_dict[first(edge.sinks)]
    #sources = [node_dict[s] for s in edge.sources]
    #sinks   = [node_dict[s] for s in edge.sinks]
    return BasicPlaceChannel(sources, sinks)
end

@doc """
    build_channel(::Type{A}, edge::TaskgrpahEdge, node_dict)

Return a concrete subtype of `PlacementChannel` for the `edge` and architecture
`A`. Argument `node_dict` is a dictionary mapping taskgraph string names to
integers.

Must initialize the required fields to their default values:
- `sources = [node_dict[s] for s in edge.sources]`
- `sinks = [node_dict[s] for s in edge.sinks]`

Other additional fields left for you to implement as needed.
""" build_channel

################################################################################
# Address Data
################################################################################

struct EmptyAddressData <: PlacementAddressData end

function build_address_data(::Type{T},
                            architecture,
                            taskgraph) where {T <: AbstractArchitecture}
    return EmptyAddressData()
end

################################################################################
# Constructor for the SA Structure
################################################################################

function SAStruct(m::Map{A,D}) where {A,D}
    @info "Building Placement Structure\n"

    architecture = m.architecture
    taskgraph    = m.taskgraph
    # First step - create the component_table.
    component_table = build_component_table(architecture)

    # Next step, build the SA Taskgraph
    node_iterator = getnodes(taskgraph)
    nodes    = [build_node(A, n, D) for n in node_iterator]
    task_table  = Dict(n.name => i for (i,n) in enumerate(node_iterator))
    # Build dictionary to map node names to indices
    node_dict = Dict(n.name => i for (i,n) in enumerate(getnodes(taskgraph)))
    # Build the basic links
    edges = [build_channel(A, n, node_dict) for n in getedges(taskgraph)]

    # Assign adjacency information to nodes.
    record_edges!(nodes, edges)

    classes, normal, special = equivalence_classes(A, taskgraph)
    # Build the map table based on the normal node equivalence classes.
    # Behold the beautiful diagonal structure
    maptables = build_maptables(architecture, normal, component_table)

    s_maptables = build_maptables(architecture, special, component_table)

    s_addresstables = build_addresstables(architecture,
                                                special,
                                                component_table)

    arraysize = size(component_table)
    distance = build_distance_table(architecture)
    # Find the maximum number of components in any address.
    max_num_components = maximum(map(length, component_table))
    grid = zeros(Int64, max_num_components, size(component_table)...)
    address_data = build_address_data(A, architecture, taskgraph)

    sa = SAStruct{A,                # Architecture Type
                  eltype(distance), # Encoding of Tile Distance
                  D,                # Dimensionality of the Architecture
                  2*D,              # 2x Architecture Dimensionality
                  D+1,              # Architecture Dimensionality + 1
                  eltype(nodes), # Type of the taskgraph nodes
                  eltype(edges), # Type of the taskgraph edges
                  typeof(address_data)  # Type of address data
                 }(
        nodes,
        edges,
        classes,
        maptables,
        s_maptables,
        s_addresstables,
        distance,
        grid,
        address_data,
        component_table,
        task_table,
    )
    # Run initial placement to return a valid structure.
    initial_placement!(sa)
    # Verify that everything worked correctly.
    verify_placement(m, sa)

    return sa
end

"""
    cleargrid(sa::SAStruct)

Set all entries in `sa.grid` to 0.
"""
cleargrid(sa::SAStruct) = sa.grid .= 0

"""
    preplace(m::Map, sa::SAStruct)

Take the placement information in `m` and apply it to `sa`.
"""
function preplace(m::Map, sa::SAStruct)
    cleargrid(sa)
    for (task_name, nodemap) in m.mapping.nodes
        # Get the address for the node
        address         = nodemap.path.address
        component_path  = nodemap.path.path
        # Get the index of the component from the component table
        component = findfirst(x -> x == component_path, sa.component_table[address])
        # Get the index to assign
        index = sa.task_table[task_name]
        # Assign the nodes
        assign(sa, index, component, address)
    end
    return nothing
end

################################################################################
# Write back method
################################################################################
"""
    record(m::Map{A,D}, sa::SAStruct)

Record the mapping from `sa` into the `mapping` field of `m`. Also confirms the
legality of the placement.
"""
function record(m::Map{A,D}, sa::SAStruct) where {A,D}
    verify_placement(m, sa)
    # Iterate through both the SA Nodes and taskgraph nodes. This is how
    # we can be sure the order of the iteration is consistent because this
    # is how the SA nodes were created in the first place.
    mapping = m.mapping
    # Reverse the task table to assign indices to tasks.
    task_table_rev = rev_dict(sa.task_table)
    for (index, sa_node) in enumerate(sa.nodes)
        # Get the mapping for the node
        address = sa_node.address
        component_index = sa_node.component
        # Get the component name in the original architecture
        component_path = sa.component_table[address][component_index]
        # Create an entry in the "Mapping" data structure
        task_node_name = task_table_rev[index]
        nodemap = mapping.nodes[task_node_name]
        nodemap.path = AddressPath(address, component_path)
    end
    return nothing
end

################################################################################
# Construction routines.
################################################################################

function build_component_table(tl::TopLevel{A,D}) where {A,D}
    # Get the dimensions of the addresses to build the array that is going to
    # hold the component table. Get the inside tuple for creation.
    table_dims = Addresses.dim_max(addresses(tl))
    component_table = fill(ComponentPath[], table_dims...)
    # Start iterating through all components at each address. Call is "ismappable"
    # function on each. If the component is mappable, add it's name to the
    # string vector at the current address.
    for (address, component) in tl.children
        paths = ComponentPath[]
        for path in walk_children(component)
            # If the component is considered mappable by the current architecture,
            # add the name of the component to the current list.
            if ismappable(A, component[path])
                push!(paths, path)
            end
        end
        component_table[address] = paths
    end
    # Condense the component table to reduce its memory footprint
    intern(component_table)
    return component_table
end

function record_edges!(nodes, edges)
    # Reverse populate the nodes so they track their edges.
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

"""
    equivalence_classes(A::Type{T}, taskgraph) where {T <: AbstractArchitecture}

Separate the nodes in the taskgraph into equivalence classes based on the rules
defined by the architecture. Expects the architecture to have defined the
following two methods:

* `isspecial(::Type{T}, t::TaskgraphNode)::Bool` - Returns whether or not the
    node should have special move considerations.
* `isequivalent(::Type{T}, a::TaskgraphNOde, b::Taskgraphnode}::Bool` - Return
    whether or not the two nodes are equivalent for placement considerations.

Returns a tuple of 3 elements:

* nodeclasses - A vector with length(nodes(taskgraph)) assigning a node index
    to an integer equivalence class. Normal equivalanece classes are represented
    by positive integers. Special classes are represented by negative integers.
* normal_node_reps - A vector of TaskgraphNodes where the node at an index
    is the representative for the equivalence class for that index.
* special_node_reps - Similar to the `normal_node_reps` but for special nodes.
    Take the negative of the index to get the number for the equivalence class.

"""
function equivalence_classes(A::Type{T}, taskgraph) where {T <: AbstractArchitecture}
    @debug "Classifying Taskgraph Nodes"
    # Allocate the node class vector. This maps task indices to a unique
    # integer ID for what class it belongs to.
    nodeclasses = Vector{Int64}(length(getnodes(taskgraph)))
    # Allocate empty vectors to serve as representatives for the normal and
    # special classes.
    normal_node_reps = TaskgraphNode[]
    special_node_reps = TaskgraphNode[]
    # Start iterating through the nodes in the taskgraph.
    for (index,node) in enumerate(getnodes(taskgraph))
        if isspecial(A, node)
            # Check if this node has an equivalent in the special node reps.
            i = findfirst(x -> isequivalent(A, x, node), special_node_reps)
            if i == 0
                # If there is no representative, i == 0 - add this node to the
                # to end of the represtatives list.
                push!(special_node_reps, node)
                # Set `i` to the last index - allows for a little bit of
                # code factoring.
                i = length(special_node_reps)
            end
            # Negate 'i' to indicate that this is a special node.
            # Store the node index
            nodeclasses[index] = -i
        else
            # Check if this node has an equivalent in the special node reps.
            i = findfirst(x -> isequivalent(A, x, node), normal_node_reps)
            if i == 0
                push!(normal_node_reps, node)
                i = length(normal_node_reps)
            end
            nodeclasses[index] = i
        end
    end

    # Debug printing.
    @debug begin
        # Get the names of normal nodes
        normal_nodes = join([n.name for n in normal_node_reps], "\n")
        # Get the names of special nodes
        special_nodes = join([n.name for n in special_node_reps], "\n")
        # Build print string
        """
        Number of Normal Representatives: $(length(normal_node_reps))
        $normal_nodes
        Number of Special Node Reps: $(length(special_node_reps))
        $special_node_reps
        """
    end
    return nodeclasses, normal_node_reps, special_node_reps
end


function build_maptables(architecture::TopLevel{A,D},
                         nodes,
                         component_table) where {A,D}
    maptype = UInt8
    # Preallocate map table
    maptable = Vector{Array{Vector{maptype},D}}(length(nodes))

    for (index,node) in enumerate(nodes)
        # Pre-allocate the map table with empty arrays.
        this_table = fill(UInt8[], size(component_table))
        # Iterate through all components of the top level architecture.
        for (address,component) in architecture.children
            # Get the mappable component from the "component_table"
            mappables = component_table[address]
            component_list = maptype[]
            for (i,path) in enumerate(mappables)
                # Get the mappable component.
                c = component[path]
                canmap(A, node, c) && push!(component_list, i)
            end
            this_table[address] = component_list
         end
         # Add the map table to the vector of tables.
         maptable[index] = this_table
    end
    intern(maptable)
    return maptable
end

function build_addresstables(architecture::TopLevel{A,D},
                             nodes,
                             component_table) where {A,D}

    # Pre-allocate the table.

    addresstables = Vector{Vector{Address{D}}}(length(nodes))
    # Iterate through each node - then through each address.
    for (index,node) in enumerate(nodes)
        this_table = Address{D}[]
        for (address, component) in architecture.children
            mappables = component_table[address]
            for (i,path) in enumerate(mappables)
                c = component[path]
                canmap(A, node, c) && push!(this_table, address)
            end
        end
        addresstables[index] = this_table
    end
    return addresstables
end

################################################################################
# BFS Routines for building the distance look up table
################################################################################
function build_distance_table(architecture::TopLevel{A,D}) where {A,D}
    # The data type for the LUT
    dtype = UInt8
    # Pre-allocate a table of the right dimensions.
    dims = Addresses.dim_max(addresses(architecture))
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
    address::Address{D}
end

function bfs!(distance::Array{U,N}, architecture::TopLevel{A,D},
              source::Address{D}, neighbor_table) where {U,N,A,D}
    # Create a queue for visiting addresses.
    q = Queue(CostAddress{U,D})
    # Add the source addresses to the queue
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items and add the source to that set.
    queued_addresses = Set{Address{D}}()
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
    dims = Int64.(Addresses.dim_max(addresses(architecture)))
    @debug "Building Neighbor Table"
    # Get the connected component dictionary
    cc = MapperCore.connected_components(architecture)
    # Create a big list of lists
    neighbor_table = Array{Vector{Address{D}}}(dims)
    for (address, set) in cc
        neighbor_table[address] = collect(set)
    end
    return neighbor_table
end

################################################################################
# Verification routine for SA Placement
################################################################################
function verify_placement(m::Map{A,D}, sa::SAStruct) where A where D
    # Assert that the SAStruct belongs to the same architecture
    @assert A == architecture(sa)
    @debug "Verifying Placement"

    bad_nodes = check_grid_population(sa)
    append!(bad_nodes, check_consistency(sa))
    append!(bad_nodes, check_mapability(m, sa))
    # Gather all the unique bad nodes and sort the final list.
    bad_nodes = sort(unique(bad_nodes))
    # Routine passes check if length of bad_nodes is 0
    passed = length(bad_nodes) == 0
    if passed
        @info "Placement Verified"
    else
        @error begin
            bad_dict = Dict{Int64, String}()
            for (i, name) in enumerate(keys(m.taskgraph.nodes))
                if i in bad_nodes
                    bad_dict[i] = name
                end
            end
            """
            Placement Failed.
            Offending Node Names:
            $bad_dict
            """
        end
    end
    return passed
end

function check_grid_population(sa::SAStruct)
    # Iterate through all entries in the grid. Record the indices encountered
    # along the way. When an index is discovered, mark it as discovered.
    #
    # If an index is found twice - this is a problem. Print an error and mark
    # the test as failed.
    #
    # After this routine - make sure that all nodes are accounted for.

    # Use this to return the indices of tasks that are troublesome.
    bad_nodes = Int64[]
    found = fill(false, length(sa.nodes))
    for g in sa.grid
        g == 0 && continue
        if found[g]
            @warn "Found node $g more than once"
            push!(bad_indices, g)
        else
            found[g] = true
        end
    end
    # Make sure all nodes have been found
    for i in 1:length(found)
        if found[i] == false
            @warn "Node $i not placed."
            push!(bad_nodes, i)
        end
    end
    return bad_nodes
end

function check_consistency(sa::SAStruct)
    bad_nodes = Int64[]
    # Verify that addresses for the nodes match the grid
    for (index,node) in enumerate(sa.nodes)
        try
            node_assigned = sa.grid[node.component, node.address]
            if index != node_assigned
                push!(bad_nodes, index)
                push!(bad_nodes, node_assigned)
                @warn """
                    Data structure inconsistency for node $index.
                    Node assigned to location: $(node.address),
                    $(node.component). Node assigned in the grid at this
                    location: $node_assigned.
                    """
            end
        catch
            @warn "Something wrong with node: $index"
            push!(bad_nodes, index)
        end
    end
    return bad_nodes
end

function check_mapability(m::Map{A,D}, sa::SAStruct) where {A,D}
    # Create a list of bad nodes for more helpful error messages.
    bad_nodes = Int64[]
    # Get the architecture parameter.
    # A = get_A(m)
    # Get the architecture itself.
    architecture = m.architecture
    # Iterate through each node in the SA
    for (index, (m_node_name, m_node)) in zip(1:length(sa.nodes), m.taskgraph.nodes)
        sa_node = sa.nodes[index]
        # Get the mapping for the node
        address = sa_node.address
        component_index = sa_node.component
        # Get the component name in the original architecture
        try
            component_path = sa.component_table[address][component_index]
            # Get the component from the architecture
            path = AddressPath(address, component_path)
            component = architecture[path]
            if !canmap(A, m_node, component)
                push!(bad_nodes, index)
                @warn """
                    Node index $index incorrectly assigned to architecture
                    node $m_node.name.
                    """
            end
        catch
            @warn "Something wrong with node index: $index"
            push!(bad_nodes, index)
        end
    end
    return bad_nodes
end
