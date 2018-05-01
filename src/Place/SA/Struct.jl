################################################################################
# Abstract Types for Placement
################################################################################
abstract type Node end
abstract type SAChannel end
abstract type TwoChannel <: SAChannel end
abstract type MultiChannel <: SAChannel end
abstract type AddressData end


@doc """
Fields required by specialized Node types:
* `address::CartesianIndex{D}` where `D` is the dimension of the architecture.
* `component_index<:Integer`
* `out_links::Vector{Int64}`
* `in_links::Vector{Int64}`
""" Node

@doc """
Fields required by specialized Node types:
* `sources::Vector{Int64}`
* `sinks::Vector{Int64}`
""" SAChannel

@doc """
Container allowing specific data to be associated with addresses in the
SAStruct. Useful for processor specific mappings such as core frequency or
leakage.
""" AddressData

@doc """
Default mapping doesn't use address specific data for its mapping objective.
The placeholder is just this empty type.
""" EmptyAddressData


################################################################################
# SA Struct
################################################################################

"""
    struct SAStruct{A,U,D,D2,D1,N,L,T}

Data structure specialized for Simulated Annealing placement.

# Constructor
    SAStruct(Map::{A,D})

# Paramters

* `A` - The Architecture Type
* `U` - Type of the Distance provider
* `D` - The dimension of the underlying architecture.
* `D1` - `D + 1`.
* `N` - Task node type.
* `L` - Edge node type.
* `T <: AddressData`` - The AddressData type.

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
* `special_addresstables::Vector{Vector{CartesianIndex{D}}}` - Used to determine the
    addresses that a special tasknode of equivalence class `i` can occupy.

    Accessed using `special_addresstables[i]`. The tasknode can be mapped to
    at least one component at each address of the returned vector.
* `distance::U` - Distance look up table from address `a` to address
    `b`. Precomputed using graph searches on the original architecture.
* `grid::Array{Int64,D1}` - Mapping from address `a`, component `i` to the
    tasknode index mapped to that location.

    Accessed via `grid[i,a]`. Returns `0` is no task is mapped to the component.
* `address_data::T` - Custom address specific datatype for implementing custom
    objective functions.
* `component_table::Array{Vector{Path{Component}},D}` - Mapping from the `SAStruct`
    to the parent `Map` type.
* `task_table::Dict{String,Int64}` - Mapping from the `SAStruct` to the parent
    `Map` type.
"""
struct SAStruct{A,U,D,D1,N,L, M <: AbstractMapTable,T}

    nodes                   ::Vector{N}
    edges                   ::Vector{L}
    maptable                ::M
    distance                ::U
    grid                    ::Array{Int64,D1}
    address_data            ::T
    # Map back fields
    component_table ::Array{Vector{Path{Component}}, D}
    task_table      ::Dict{String,Int64}
end

# Convenience decoding methods
dimension(::SAStruct{A,U,D})  where {A,U,D} = D
architecture(::SAStruct{A})   where {A} = A
nodetype(s::SAStruct) = typeof(s.nodes)
edgetype(s::SAStruct) = typeof(s.edges)
distancetype(::SAStruct{A,U}) where {A,U} = U

################################################################################
# Basis SA Node
################################################################################

mutable struct BasicNode{T} <: Node
    location ::T
    out_edges::Vector{Int64}
    in_edges ::Vector{Int64}
end

# Node Interface
location(n::Node)               = n.location
assign(n::Node, l)              = (n.location = l)
MapperCore.getaddress(n::Node)  = getaddress(n.location)
getcomponent(n::Node)           = getcomponent(n.location)

# -------------
# Construction
# -------------
function build_node(::Type{T}, n::TaskgraphNode, x) where {T <: AbstractArchitecture}
    return BasicNode(x, Int64[], Int64[])
end

function setup_node_build(::Type{A}, t::Taskgraph, D, isflat::Bool) where A <: AbstractArchitecture
    init = isflat ? zero(CartesianIndex{D}) : Location{D}()
    return [build_node(A, n, init) for n in getnodes(t)]
end

@doc """
    build_node(::Type{A}, n::TaskgraphNode, D::Integer)

Construct an `Node` for the given taskgraph node and architecture `A`
with dimension `D`.

Must initialize the required fields to their default values:
- `address = CartesianIndex{D}()`
- `component = 0`
- `out_edges = Int[]`
- `in_edges  = Int[]`

Other additional fields left for your to implement as needed.
""" build_node

################################################################################
# Basis SA Edge
################################################################################

struct BasicChannel <: TwoChannel
    source::Int64
    sink  ::Int64
end

struct BasicMultiChannel <: MultiChannel
    sources ::Vector{Int64}
    sinks   ::Vector{Int64}
end

function setup_channel_build(::Type{A}, taskgraph) where A <: AbstractArchitecture
    edges = getedges(taskgraph)
    nodes = getnodes(taskgraph)
    node_dict = Dict(n.name => i for (i,n) in enumerate(nodes))
    # Make source and sink vectors
    sources = map(edges) do edge
        [node_dict[i] for i in edge.sources]
    end
    sinks = map(edges) do edge
        [node_dict[i] for i in edge.sinks]
    end
    # Pass this to the `build_channels` function
    return build_channels(A, edges, sources, sinks)
end

function build_channels(::Type{A}, edges, sources, sinks) where A <: AbstractArchitecture

    # Get the maximum length of sources and sinks. Use this to determine
    # which type of channels to build.
    max_length = max(maximum.((length.(sources), length.(sinks)))...)
    if max_length == 1
        return [BasicChannel(first(i), first(j)) for (i,j) in zip(sources, sinks)]
    else
        return [BasicMultiChannel(i,j) for (i,j) in zip(sources, sinks)]
    end
end

################################################################################
# Address Data
################################################################################

struct EmptyAddressData <: AddressData end
"""
    build_address_data(::Type{A}, arch::TopLevel, component_table) where A <: AbstractArchitecture

Default constructor for address data. Creates an array with a similar structure
to `component_table`. For each path in `component_table`, calls:
```
build_address_data(A, component)
```
"""
function build_address_data(
        ::Type{A}, 
        arch::TopLevel, 
        component_table;
        isflat = false
       ) where A <: AbstractArchitecture

    if isflat
        map(component_table) do paths
            build_address_data(A, arch[first(paths)])
        end
    else
        map(component_table) do paths
            [build_address_data(A, arch[path]) for path in paths]
        end
    end
end

# Define two methods to correctly handle the flat architecture case where the
# elements of `component_table` are just Path{Component} instead of 
# Vector{Path{Component}}
call_address_data(arch::TopLevel{A}, path::Path) where A = build_address_data(A, arch[path])
function call_address_data(arch::TopLevel{A}, paths::Vector{<:Path}) where A
    return [build_address_data(A, arch[path]) for path in paths]
end

################################################################################
# Constructor for the SA Structure
################################################################################

function SAStruct(m::Map{A,D};
                  distance = build_distance_table(m.architecture),
                  # Enable the flat-architecture optimization.
                  enable_flattness = true,
                  # Enable address-specific data.
                  enable_address = true,
                  kwargs...
                 ) where {A,D}

    @debug "Building SA Placement Structure\n"

    arch  = m.architecture
    taskgraph     = m.taskgraph
    # Create the component_table.
    component_table = build_component_table(arch)

    # If the maximum number of components is 1, we can apply the fast-node
    #   optimizations
    if enable_flattness
        isflat = maximum(map(x -> length(x), component_table)) == 1
    else
        isflat = false
    end
    isflat && @debug "Applying Flat Architecture Optimization"

    nodes      = setup_node_build(A, taskgraph, D, isflat)
    task_table = Dict(n.name => i for (i,n) in enumerate(getnodes(taskgraph)))

    #------------------------------#
    # Build the channel containers #
    #------------------------------#
    edges = setup_channel_build(A, taskgraph)
    @debug """
        Node Type: $(typeof(nodes))
        Edge Type: $(typeof(edges))
        """

    # Assign adjacency information to nodes.
    record_edges!(nodes, edges)

    #----------------------------------------------------#
    # Obtain task equivalence classes from the taskgraph #
    #----------------------------------------------------#
    maptable = MapTable(arch, taskgraph, component_table, isflat = isflat)

    arraysize = size(component_table)
    if isflat
        grid = zeros(size(component_table)...)
    else
        max_num_components = maximum(map(length, component_table))
        grid = zeros(Int64, max_num_components, size(component_table)...)
    end

    if enable_address
        address_data = build_address_data(A, arch, component_table, isflat = isflat)
    else
        address_data = EmptyAddressData()
    end

    sa = SAStruct{A,                    # Architecture Type
                  typeof(distance),     # Encoding of Tile Distance
                  D,                    # Dimensionality of the Architecture
                  ndims(grid),          # Architecture Dimensionality + 1
                  eltype(nodes),        # Type of the taskgraph nodes
                  eltype(edges),        # Type of the taskgraph edges
                  typeof(maptable),
                  typeof(address_data)  # Type of address data
                 }(
        nodes,
        edges,
        maptable,
        distance,
        grid,
        address_data,
        component_table,
        task_table,
    )

    # Run initial placement and verify result.
    initial_placement!(sa)
    verify_placement(m, sa)
    return sa
end

"""
    cleargrid(sa::SAStruct)

Set all entries in `sa.grid` to 0.
"""
@inline cleargrid(sa::SAStruct) = clear(sa.grid)
@inline clear(x::Array{T}) where T = x .= zero(T)


"""
    preplace(m::Map, sa::SAStruct)

Take the placement information in `m` and apply it to `sa`.
"""
function preplace(m::Map, sa::SAStruct)
    cleargrid(sa)
    for (taskname, path) in m.mapping.nodes
        address = getaddress(m.architecture, path)
        component = Compat.findfirst(x -> x == path, sa.component_table[address])
        # Get the index to assign
        index = sa.task_table[taskname]
        # Assign the nodes
        if typeof(sa.nodes[index].location) <: CartesianIndex
            assign(sa, index, address)
        else
            assign(sa, index, Location(address, component))
        end
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
    mapping = m.mapping
    task_table_rev = rev_dict(sa.task_table)

    for (index, node) in enumerate(sa.nodes)
        # Get the mapping for the node
        address         = getaddress(node)
        component_index = getcomponent(node)
        # Get the component name in the original architecture
        path = sa.component_table[address][component_index]
        task_node_name  = task_table_rev[index]
        # Create an entry in the "Mapping" data structure
        mapping.nodes[task_node_name] = path
    end
    return nothing
end

function record(nodes, i, edge::TwoChannel)
    push!(nodes[edge.source].out_edges, i)
    push!(nodes[edge.sink].in_edges, i)
    return nothing
end

function record(nodes, i, edge::MultiChannel)
    for j in edge.sources
        push!(nodes[j].out_edges,i)
    end
    for j in edge.sinks
        push!(nodes[j].in_edges,i)
    end
    return nothing
end

function record_edges!(nodes, edges)
    # Reverse populate the nodes so they track their edges.
    for (i,edge) in enumerate(edges)
        record(nodes, i, edge)
    end
    return nothing
end


function build_component_table(arch::TopLevel{A,D}) where {A,D}
    offset = getoffset(arch)
    # Get the dimensions of the addresses to build the array that is going to
    # hold the component table. Get the inside tuple for creation.
    table_dims = dim_max(addresses(arch)) .+ offset.I
    component_table = fill(Path{Component}[], table_dims...)

    for (name, component) in arch.children
        # Collect full paths for all components that are mappable.
        paths = [catpath(name, p)
                 for p in walk_children(component)
                 if ismappable(A, component[p])
                ]
        # Account for architecture to array address offset
        component_table[getaddress(arch, name) + offset] = paths
    end
    # Condense the component table to reduce its memory footprint
    intern(component_table)
    return component_table
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
function equivalence_classes(::Type{A}, taskgraph) where {A <: AbstractArchitecture}
    @debug "Classifying Taskgraph Nodes"
    # Allocate the node class vector. This maps task indices to a unique
    # integer ID for what class it belongs to.
    @compat nodeclasses = Vector{Int64}(uninitialized, length(getnodes(taskgraph)))
    # Allocate empty vectors to serve as representatives for the normal and
    # special classes.
    normal_node_reps  = TaskgraphNode[]
    special_node_reps = TaskgraphNode[]
    # Start iterating through the nodes in the taskgraph.
    for (index,node) in enumerate(getnodes(taskgraph))
        if isspecial(A, node)
            # Check if this node has an equivalent in the special node reps.
            i = Compat.findfirst(x -> isequivalent(A, x, node), special_node_reps)
            if i == nothing
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
            i = Compat.findfirst(x -> isequivalent(A, x, node), normal_node_reps)
            if i == nothing
                push!(normal_node_reps, node)
                i = length(normal_node_reps)
            end
            nodeclasses[index] = i
        end
    end

    # Scoping issues with "n" and "i" if build inside @debug block.
    normal_nodes  = join([n.name for n in normal_node_reps], "\n")
    special_nodes = join([i.name for i in special_node_reps], "\n")
    @debug begin
        """
        Number of Normal Representatives: $(length(normal_node_reps))
        $normal_nodes
        Number of Special Node Reps: $(length(special_node_reps))
        $special_nodes
        """
    end

    return nodeclasses, normal_node_reps, special_node_reps
end

function build_normal_lut(arch::TopLevel{A,D}, nodes, component_table) where {A,D}
    maptable = map(nodes) do node
        map(component_table) do paths
            [index for (index,path) in enumerate(paths) if canmap(A, node, arch[path])]
        end
    end
    intern(maptable)
    return maptable
end

function build_special_lut(arch::TopLevel{A,D}, nodes, component_table) where {A,D}
    return map(nodes) do node
        locations_for_node = Location{D}[]
        @compat for address in CartesianIndices(component_table)
            for (index, path) in enumerate(component_table[address])
                if canmap(A, node, arch[path])
                    push!(locations_for_node, Location(address, index))
                end
            end
        end
        return locations_for_node
    end
end

################################################################################
# BFS Routines for building the distance look up table
################################################################################
function build_distance_table(arch::TopLevel{A,D}) where {A,D}
    # The data type for the LUT
    dtype = UInt8
    # Pre-allocate a table of the right dimensions.
    # Replicate the dimensions once to get a 2D sized LUT.
    dims = getdims(arch)
    distance = fill(typemax(dtype), dims..., dims...)

    neighbor_dict = build_neighbor_dict(arch)

    @debug "Building Distance Table"
    # Run a BFS for each starting address
    @compat for address in keys(neighbor_dict)
        bfs!(distance, address, neighbor_dict)
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

# Implementation note:
# This function is only correct if the cost of each link is 1. If cost can vary,
# will have to code this using some kind of shortest path formulation.
function bfs!(distance::Array{U,N}, source::Address{D}, neighbor_dict) where {U,N,D}
    # Create a queue for visiting addresses. Add source to get into the loop.
    q = Queue(CostAddress{U,D})
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items to avoid visiting the same address twice.
    seen = Set{Address{D}}()
    push!(seen, source)

    # Basic BFS.
    while !isempty(q)
        u = dequeue!(q)
        distance[source, u.address] = u.cost
        for v in neighbor_dict[u.address]
            in(v, seen) && continue

            enqueue!(q, CostAddress(u.cost + one(U), v))
            push!(seen, v)
        end
    end

    return nothing
end

function build_neighbor_dict(arch::TopLevel{A,D}) where {A,D}
    @debug "Building Neighbor Table"
    # Get the connected component dictionary
    cc = MapperCore.connected_components(arch)
    offset = getoffset(arch)
    return Dict(a + offset => collect(s) .+ offset for (a,s) in cc)
end

################################################################################
# Verification routine for SA Placement
################################################################################
function verify_placement(m::Map{A,D}, sa::SAStruct{A}) where A where D
    # Assert that the SAStruct belongs to the same architecture
    @debug "Verifying Placement"

    bad_nodes = check_grid_population(sa)
    append!(bad_nodes, check_consistency(sa))
    append!(bad_nodes, check_mapability(m, sa))
    # Gather all the unique bad nodes and sort the final list.
    bad_nodes = sort(unique(bad_nodes))
    # Routine passes check if length of bad_nodes is 0
    passed = length(bad_nodes) == 0
    if passed
        @debug "Placement Verified"
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
            push!(bad_nodes, g)
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
        node_assigned = sa.grid[location(node)]
        if index != node_assigned
            push!(bad_nodes, index)
            push!(bad_nodes, node_assigned)
            @warn """
                Data structure inconsistency for node $index.
                Node assigned to location: $(location(node)).

                Node assigned in the grid at this location: $node_assigned.
                """
        end
    end
    return bad_nodes
end

function check_mapability(m::Map{A,D}, sa::SAStruct) where {A,D}

    bad_nodes = Int64[]
    arch = m.architecture
    # Iterate through each node in the SA
    for (index, (m_node_name, m_node)) in enumerate(m.taskgraph.nodes)
        sa_node = sa.nodes[index]
        # Get the mapping for the node
        address = getaddress(sa_node)
        component = getcomponent(sa_node)
        # Get the component name in the original architecture
        path = sa.component_table[address][component]
        # Get the component from the architecture
        component = arch[path]
        if !canmap(A, m_node, component)
            push!(bad_nodes, index)
            @warn """
                Node index $index incorrectly assigned to architecture
                node $(m_node.name).
                """
        end
    end
    return bad_nodes
end
