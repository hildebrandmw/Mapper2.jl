# Work out a way of doing "representatives" for each

#=
The structure that will be used for placement in the new taskgraph.

Will take a Map structure and spawn off its own specialized structure.
=#
"""
Fields required by specialized SANode types:
* address   ::Address{D} where D is the dimension of the architecture.
* component_index <: Integer
* out_links ::Vector{Int64}
* in_links  ::Vector{Int64}
"""
abstract type AbstractSANode end

"""
Fields required by specialized SANode types:
* sources   ::Vector{Int64}
* sinks     ::Vector{Int64}
"""
abstract type AbstractSAEdge end

"""
Container allowing specific data to be associated with addresses in the 
SAStruct. Useful for processor specific mappings such as core frequency or
leakage.
"""
abstract type AbstractAddressData end

"""
Default mapping doesn't use address specific data for its mapping objective.
The placeholder is just this empty type.
"""
struct EmptyAddressData <: AbstractAddressData end

"""
Paramters:

* `A` - The Architecture Type
* `U` - Element type for the distance calculation LUT.
* `D` - The dimension of the underlying architecture.
* `D2`- Twice `D`. (still haven't figured out how to make julia to arithmetic
                    with type parameters)
* `D1` - `D + 1`.
* `N` - Task node type.
* `L` - Edge node type.
* `T` - The AddressData type.
"""
mutable struct SAStruct{A,U,D,D2,D1,N <: AbstractSANode,L <: AbstractSAEdge,
                        T <: AbstractAddressData}
    "Specialized node type."
    nodes::Vector{N}
    "Specialized link type."
    edges::Vector{L}
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
    maptables::Vector{Array{Vector{UInt8},D}}
    """
    The special map tables where a set of valid destination addresses for a node
    class are pre-computed and a valid destination address is chosen for move
    generation.
    """
    special_maptables::Vector{Array{Vector{UInt8}, D}}
    special_addresstables::Vector{Vector{Address{D}}}
    """
    Distance look-up table. This is twice the size of the the address dimension
    to allow distances to be calculated from any source address to any
    destination address.
    """
    distance::Array{U,D2}
    """
    Lookup table to take a component index and address and get the node index
    mapped to that location.

    Access this as grid[component_index, address]. Component index comes first
    because Julia column major.
    """
    grid::Array{Int64, D1}
    """
    Address specific data used for custom objective functions.
    """
    address_data::T
    #=
    Component tables for tracking local component references to the global
    reference in the Map data type
    =#
    component_table::Array{Vector{ComponentPath}, D}
    task_table::Dict{String,Int64}
end



# Convenience decoding methods - this is kinda gross.
dimension(::SAStruct{A,U,D,D2,D1,N,L,T})      where {A,U,D,D2,D1,N,L,T} = D
architecture(::SAStruct{A,U,D,D2,D1,N,L,T})   where {A,U,D,D2,D1,N,L,T} = A
nodetype(::SAStruct{A,U,D,D2,D1,N,L,T})       where {A,U,D,D2,D1,N,L,T} = N
edgetype(::Type{SAStruct{A,U,D,D2,D1,N,L,T}}) where {A,U,D,D2,D1,N,L,T} = L
distancetype(::SAStruct{A,U,D,D2,D1,N,L,T})   where {A,U,D,D2,D1,N,L,T} = U

################################################################################
# Templates for the basic task and link types
################################################################################

# TODO: Think about how this has to get dispatched depending on taskgraphs AND
# architectures.
mutable struct BasicSANode{D} <: AbstractSANode
    address         ::Address{D}
    component       ::Int64
    out_edges       ::Vector{Int64}
    in_edges        ::Vector{Int64}
end
# Fallback constructor for task nodes.
function build_sa_node(::Type{T}, n::TaskgraphNode, D) where {T <: AbstractArchitecture}
    return BasicSANode(Address{D}(), 0, Int64[], Int64[])
end

struct BasicSAEdge <: AbstractSAEdge
    sources::Vector{Int64}
    sinks  ::Vector{Int64}
end

function build_sa_edge(::Type{T}, edge::TaskgraphEdge, node_dict) where {T <: AbstractArchitecture}
    # Build up adjacency lists.
    # Sources in the task-graphs are strings so we can just use the
    # node-dictionary to convert them into integers.
    sources = [node_dict[s] for s in edge.sources]
    sinks   = [node_dict[s] for s in edge.sinks]
    return BasicSAEdge(sources, sinks)
end

function build_address_data(::Type{T}, 
                            architecture, 
                            taskgraph) where {T <: AbstractArchitecture}
    return EmptyAddressData()
end

################################################################################
# Constructor for the SA Structure
################################################################################

"""
    SAStruct(m::Map{A,D})

Create a SAStruct from the provided map `m`. Returned structure does not
have any kind of initial placement.
"""
function SAStruct(m::Map{A,D}) where {A,D}
    DEBUG && debug_print(:start, "Building Placement Structure\n")

    architecture = m.architecture
    taskgraph    = m.taskgraph
    # First step - create the component_table.
    component_table = build_component_table(architecture)

    # Next step, build the SA Taskgraph
    node_iterator = getnodes(taskgraph)
    sa_nodes    = [build_sa_node(A, n, D) for n in node_iterator]
    task_table  = Dict(n.name => i for (i,n) in enumerate(node_iterator))
    # Build dictionary to map node names to indices
    node_dict = Dict(n.name => i for (i,n) in enumerate(getnodes(taskgraph)))
    # Build the basic links
    sa_edges = [build_sa_edge(A, n, node_dict) for n in getedges(taskgraph)]
    # Reverse populate the nodes so they track their edges.
    record_edges!(sa_nodes, sa_edges)

    #=
    Need to do the following:

    1. Get node equivalence classes
    2. Get get component equivalence classes
    3. Profit
    =#
    nodeclass, normal_node_reps, special_node_reps = get_node_equivalence_classes(
            A,
            taskgraph
        )
    # Build the map table based on the normal node equivalence classes.
    # Behold the beautiful diagonal structure
    maptables = build_maptables(architecture, normal_node_reps, component_table)

    s_maptables = build_maptables(architecture, special_node_reps, component_table)

    s_addresstables = build_addresstables(architecture,
                                                special_node_reps,
                                                component_table)

    arraysize = size(component_table)
    distance = build_distance_table(architecture)
    # Find the maximum number of components in any address.
    max_num_components = maximum(map(x -> length(x), component_table))
    grid = zeros(Int64, max_num_components, size(component_table)...)
    address_data = build_address_data(A, architecture, taskgraph)

    sa = SAStruct{A,                # Architecture Type
                  eltype(distance), # Encoding of Tile Distance
                  D,                # Dimensionality of the Architecture
                  2*D,              # 2x Architecture Dimensionality
                  D+1,              # Architecture Dimensionality + 1
                  eltype(sa_nodes), # Type of the taskgraph nodes
                  eltype(sa_edges), # Type of the taskgraph edges
                  typeof(address_data)  # Type of address data
                 }(
        sa_nodes,
        sa_edges,
        nodeclass,
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

Take the placement information 
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

Record the mapping from `sa` into the `mapping` field of `m`. Also confims the
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
    table_dims = address_max(addresses(tl))
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

"""
    get_node_equivalence_classes(A::Type{T}, taskgraph) where {T <: AbstractArchitecture}

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
function get_node_equivalence_classes(A::Type{T}, taskgraph) where {T <: AbstractArchitecture}
    DEBUG && debug_print(:start, "Classifying Taskgraph Nodes\n")
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

    ##################################################
    # Print out statistics if DEBUG mode is turned on.
    ##################################################
    if DEBUG
        debug_print(:info, "Number of Normal Representatives: ")
        debug_print(:none, length(normal_node_reps), "\n")
        for node in normal_node_reps
            debug_print(:none, node.name, "\n")
        end
        debug_print(:info, "Number of Special Representatives: ")
        debug_print(:none, length(special_node_reps), "\n")
        for node in special_node_reps
            debug_print(:none, node.name, "\n")
        end
    end
    return nodeclasses, normal_node_reps, special_node_reps
end


function build_maptables(architecture::TopLevel{A,D}, nodes, component_table) where {A,D}
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
    dims = address_max(addresses(architecture))
    # Replicate the dimensions once to get a 2D sized LUT.
    distance = Array{dtype}(dims..., dims...)
    # Get the neighbor table for finding adjacent components in the top level.
    neighbor_table = build_neighbor_table(architecture)

    DEBUG && debug_print(:start, "Building Distance Table\n")
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
    dims = Int64.(address_max(addresses(architecture)))
    DEBUG && debug_print(:start, "Building Neighbor Table\n")
    # Get the connected component dictionary
    cc = Architecture.connected_components(architecture)
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
    DEBUG && debug_print(:substart, "Verifying Placement\n")

    bad_nodes = check_grid_population(sa)
    append!(bad_nodes, check_consistency(sa))
    append!(bad_nodes, check_mapability(m, sa))
    # Gather all the unique bad nodes and sort the final list.
    bad_nodes = sort(unique(bad_nodes))
    # Routine passes check if length of bad_nodes is 0
    passed = length(bad_nodes) == 0
    if DEBUG
        if passed
            debug_print(:success, "Placement verified :)\n")
        else
            debug_print(:error, "Placement failed :(\n")
            debug_print(:error, "\nOffending Node Names:\n")
            #=
            Convert the bad indices to the names of the offending nodes
            by iterating through the names in the taskgraph nodes. If there's
            a match with one of the offending indices, print both the index
            and the node name to the console.
            =#
            bad_dict = Dict{Int64, String}()
            for (i, name) in enumerate(keys(m.taskgraph.nodes))
                if i in bad_nodes
                    bad_dict[i] = name
                end
            end
            display(bad_dict)
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
            debug_print(:error, "Found node ", g, " more than once\n")
            push!(bad_indices, g)
        else
            found[g] = true
        end
    end
    # Make sure all nodes have been found
    for i in 1:length(found)
        if found[i] == false
            debug_print(:error, "Node ", i, " not placed.\n")
            push!(bad_nodes, i)
        end
    end
    return bad_nodes
end

function check_consistency(sa::SAStruct)
    bad_nodes = Int64[]
    # Verify that addresses for the nodes match the grid
    for (index,node) in enumerate(sa.nodes)
        node_assigned = sa.grid[node.component, node.address]
        if index != node_assigned
            push!(bad_nodes, index)
            push!(bad_nodes, node_assigned)
            passed = false
            debug_print(:error, 
                 "Data structure inconsistency for node ", 
                 index, ". Nodes assigned location: ", node.address,
                 ", ", node.component, ". Node assigned in the grid",
                 " at this location: ", node_assigned, ".\n")
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
        component_path = sa.component_table[address][component_index]
        # Get the component from the architecture
        path = AddressPath(address, component_path)
        component = architecture[path]
        if !canmap(A, m_node, component)
            push!(bad_nodes, index)
            debug_print(:error, "Node index ", index, 
                             " incorrectly assigned to architecture node ",
                             m_node_name, ".\n")
        end
    end
    return bad_nodes
end
