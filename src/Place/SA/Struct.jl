################################################################################
# Abstract Types for Placement
################################################################################
abstract type SANode end
abstract type SAChannel end
abstract type TwoChannel <: SAChannel end
abstract type MultiChannel <: SAChannel end
abstract type AddressData end


@doc """
Fields required by specialized SANode types:
* `address::CartesianIndex{D}` where `D` is the dimension of the architecture.
* `component_index<:Integer`
* `out_links::Vector{Int64}`
* `in_links::Vector{Int64}`
""" SANode

@doc """
Fields required by specialized SANode types:
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
Datastructure for simulated annealing placement.

Important parameters:

* `A` - The concrete Architecture type.


Constructor
-----------
Arguments:
* `m`: The `Map` to translate into an `SAStruct`.

Keyword Arguments:
* `distance`: The distance type to use. Defaults: [`BasicDistance`](@ref)

* `enable_flattness :: Bool`: Enable the flat architecture optimization if
    it is applicable. Default: `true`.

* `enable_address :: Bool`: Enable address-specific data to be incorporated
    into the struct. Default: `false`.

* `aux`: Auxiliary data struct to provide any extra information that may be
    needed for specializations of placement. Default: `nothing`.
"""
struct SAStruct{
        A <: Architecture, 
        U <: SADistance,
        D,
        D1,
        N <: SANode,
        L <: SAChannel, 
        M <: AbstractMapTable,
        T <: AddressData,
        Q
    }

    "`Vector{N}`: Container of nodes."
    nodes :: Vector{N}
    "`Vector{L}`: Container of edges."
    channels :: Vector{L}
    maptable :: M
    distance :: U
    grid :: Array{Int64,D1}
    address_data :: T
    aux :: Q
    # Map back fields
    pathtable :: Array{Vector{Path{Component}}, D}
    tasktable :: Dict{String,Int64}
end

# Convenience decoding methods
dimension(::SAStruct{A,U,D})  where {A,U,D} = D
architecture(::SAStruct{A})   where {A} = A
nodetype(s::SAStruct) = typeof(s.nodes)
channeltype(s::SAStruct) = typeof(s.channels)
distancetype(::SAStruct{A,U}) where {A,U} = U

isflat(x) = false
isflat(::SAStruct{A,U,D,D}) where {A,U,D} = true
Base.eltype(sa_struct::SAStruct) = location_type(sa_struct.maptable)



################################################################################
# Basis SA Node
################################################################################

"""
The standard implementation of `SANode`.
"""
mutable struct BasicNode{T} <: SANode
    "Location this node is assigned in the architecture. Must be parametric."
    location :: T
    "The class of this node."
    class :: Int 
    "Adjacency list of outgoing channels."
    outchannels :: Vector{Int64}
    "Adjacency list of incoming channels."
    inchannels  :: Vector{Int64}
end

# Node Interface
@inline location(n::SANode)           = n.location
@inline assign(n::SANode, l)          = (n.location = l)
@inline getclass(n::SANode)           = n.class
@inline setclass!(n::SANode, class)   = n.class = class
@inline getaddress(n::SANode)         = getaddress(n.location)
@inline getindex(n::SANode)           = getindex(n.location)

isnormal(node::SANode) = isnormal(class(node))
isnormal(class::Int64) = class > 0

# -------------
# Construction
# -------------
function buildnode(::Type{A}, n::TaskgraphNode, x) where {A <: Architecture}
    return BasicNode(x, 0, Int64[], Int64[])
end

function setup_node_build(::Type{A}, t::Taskgraph, D, isflat::Bool) where A <: Architecture
    init = isflat ? zero(CartesianIndex{D}) : Location{D}()
    return [buildnode(A, n, init) for n in getnodes(t)]
end

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

function setup_channel_build(::Type{A}, taskgraph) where A <: Architecture
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

function build_channels(::Type{A}, edges, sources, sinks) where A <: Architecture

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
    build_address_data(::Type{A}, arch::TopLevel, pathtable) where A <: Architecture

Default constructor for address data. Creates an array with a similar structure
to `pathtable`. For each path in `pathtable`, calls:
```
build_address_data(A, component)
```
"""
function build_address_data(
        ::Type{A}, 
        arch::TopLevel{A,D}, 
        pathtable;
        isflat = false
    ) where {A,D}

    comp(a) = [build_address_data(A, arch[path]) for path in pathtable[a]]
    address_data = Dict(
        a => comp(a) 
        for a in CartesianIndices(pathtable)
        if length(pathtable[a]) > 0
    )
    # If the flat optimization is turned on - remove the vectors from the values
    # in the dictionary.
    if isflat
        return Dict(k => first(v) for (k,v) in address_data)
    else
        return address_data
    end
end

# Define two methods to correctly handle the flat architecture case where the
# elements of `pathtable` are just Path{Component} instead of 
# Vector{Path{Component}}
call_address_data(arch::TopLevel{A}, path::Path) where A = build_address_data(A, arch[path])
function call_address_data(arch::TopLevel{A}, paths::Vector{<:Path}) where A
    return [build_address_data(A, arch[path]) for path in paths]
end

################################################################################
# Constructor for the SA Structure
################################################################################
function SAStruct(
        m::Map{A,D};
        distance = BasicDistance(m.architecture),
        # Enable the flat-architecture optimization.
        enable_flattness = true,
        # Enable address-specific data.
        enable_address = false,
        aux = nothing,
        kwargs...
    ) where {A,D}

    @debug "Building SA Placement Structure\n"

    # Unpack some data structures for easier reference.
    arch = m.architecture
    taskgraph = m.taskgraph

    # Create an array mapping Addresses to Vector{Path{Component}} where each
    # Path{Component} is a mappable component in the architecture.
    #
    # Note that address translation happens here. That is, if there are addresses
    # in the parent architecture that nave zero or negative indices, the addresses
    # are shifted in the `pathtable` so the lowest potential address is (1,1,1 ...)
    #
    # While this sounds like it may be confusing, it actually works out quite 
    # well:
    # * When referencing addresses on the SAStruct side of things, just use the
    #   CartesianIndex/Address used to access a certain location.
    # * When referencing something on the TopLevel side of this construction/
    #   destruction, use the overloaded "getindex" methods usint the 
    #   Path{Component} objects and evertyhing tends to magically work itself
    #   out.
    pathtable = build_pathtable(arch)

    # If the maximum number of components is 1, we can apply the fast-node
    # optimizations. This lets us get rid of some vectors and store more data
    # inline, which means fewer pointer chases! :D
    isflat = enable_flattness && (maximum(map(x -> length(x), pathtable)) == 1)
    isflat && @debug "Applying Flat Architecture Optimization"

    # Build SA Node types and make a record mapping node name to the index of
    # that nodes representation in this data structure.
    nodes = setup_node_build(A, taskgraph, D, isflat)
    tasktable = Dict(n.name => i for (i,n) in enumerate(getnodes(taskgraph)))

    # Build Channel
    channels = setup_channel_build(A, taskgraph)
    @debug """
        Node Type: $(typeof(nodes))
        Edge Type: $(typeof(channels))
        """

    # Assign adjacency information to nodes.
    record_channels!(nodes, channels)

    #----------------------------------------------------#
    # Obtain task equivalence classes from the taskgraph #
    #----------------------------------------------------#
    equivalence_classes = task_equivalence_classes(A, taskgraph)

    # Assign each node with its given classification.
    for (index, class) in enumerate(equivalence_classes.classes)
        setclass!(nodes[index], class)
    end

    maptable = MapTable(arch, equivalence_classes, pathtable, isflat = isflat)
    if isflat
        grid = zeros(size(pathtable)...)
    else
        max_num_components = maximum(map(length, pathtable))
        grid = zeros(Int64, max_num_components, size(pathtable)...)
    end

    if enable_address
        address_data = build_address_data(A, arch, pathtable, isflat = isflat)
    else
        address_data = EmptyAddressData()
    end

    sa = SAStruct{
        A,                    # Architecture Type
        typeof(distance),     # Encoding of Tile Distance
        D,                    # Dimensionality of the Architecture
        ndims(grid),          # Architecture Dimensionality + 1
        eltype(nodes),        # Type of the taskgraph nodes
        eltype(channels),     # Type of the taskgraph channels
        typeof(maptable),
        typeof(address_data),  # Type of address data
        typeof(aux),
     }(
        nodes,
        channels,
        maptable,
        distance,
        grid,
        address_data,
        aux,
        pathtable,
        tasktable,
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

    offset = getoffset(m.architecture)
    for (taskname, path) in m.mapping.nodes
        address = getaddress(m.architecture, path) + offset
        component = findfirst(isequal(path), sa.pathtable[address])
        # Get the index to assign
        index = sa.tasktable[taskname]
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
    tasktable_rev = rev_dict(sa.tasktable)

    for (index, node) in enumerate(sa.nodes)
        # Get the mapping for the node
        address   = getaddress(node)
        pathindex = getindex(node)
        # Get the component name in the original architecture
        path = sa.pathtable[address][pathindex]
        task_node_name  = tasktable_rev[index]
        # Create an entry in the "Mapping" data structure
        mapping.nodes[task_node_name] = path
    end
    return nothing
end

function record(nodes, i, channel::TwoChannel)
    push!(nodes[channel.source].outchannels, i)
    push!(nodes[channel.sink].inchannels, i)
    return nothing
end

function record(nodes, i, channel::MultiChannel)
    for j in channel.sources
        push!(nodes[j].outchannels,i)
    end
    for j in channel.sinks
        push!(nodes[j].inchannels,i)
    end
    return nothing
end

function record_channels!(nodes, channels)
    # Reverse populate the nodes so they track their channels.
    for (i,channel) in enumerate(channels)
        record(nodes, i, channel)
    end
    return nothing
end


function build_pathtable(arch::TopLevel{A,D}) where {A,D}
    offset = getoffset(arch)
    @debug "Architecture Offset: $offset"
    # Get the dimensions of the addresses to build the array that is going to
    # hold the component table. Get the inside tuple for creation.
    table_dims = dim_max(addresses(arch)) .+ offset.I
    pathtable = fill(Path{Component}[], table_dims...)

    for (name, component) in arch.children
        # Collect full paths for all components that are mappable.
        paths = [
            catpath(name, p) 
            for p in walk_children(component) 
            if ismappable(A, component[p])
        ]

        # Account for architecture to array address offset
        pathtable[getaddress(arch, name) + offset] = paths
    end
    # Condense the mappable path table to reduce its memory footprint
    intern(pathtable)
    return pathtable
end

"""
    equivalence_classes(A::Type{T}, taskgraph) where {T <: Architecture}

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
* normal_reps - A vector of TaskgraphNodes where the node at an index
    is the representative for the equivalence class for that index.
* special_reps - Similar to the `normal_reps` but for special nodes.
    Take the negative of the index to get the number for the equivalence class.

"""
function task_equivalence_classes(
            ::Type{A}, 
            taskgraph::Taskgraph,
           ) where {A <: Architecture}

    @debug "Classifying Taskgraph Nodes"
    # Allocate the node class vector. This maps task indices to a unique
    # integer ID for what class it belongs to.
    classes = zeros(Int64, length(getnodes(taskgraph)))
    # Allocate empty vectors to serve as representatives for the normal and
    # special classes.
    normal_reps  = TaskgraphNode[]
    special_reps = TaskgraphNode[]
    # Start iterating through the nodes in the taskgraph.
    for (index,node) in enumerate(getnodes(taskgraph))
        if isspecial(A, node)
            # Set this to the index of an existing node if it exists. Otherwise,
            # add this node as a representative and give it the next index.
            i = findfirst(x -> isequivalent(A, x, node), special_reps)
            if i == nothing
                push!(special_reps, node)
                i = length(special_reps)
            end
            # Negate "i" to indicate a special class.
            classes[index] = -i
        else
            # Same as with the special nodes.
            i = findfirst(x -> isequivalent(A, x, node), normal_reps)
            if i == nothing
                push!(normal_reps, node)
                i = length(normal_reps)
            end
            # Keep this index positive to indicate normal node.
            classes[index] = i
        end
    end

    # Scoping issues with "n" and "i" if build inside @debug block.
    normal_nodes  = join([n.name for n in normal_reps], "\n")
    special_nodes = join([i.name for i in special_reps], "\n")
    @debug begin
        """
        Number of Normal Representatives: $(length(normal_reps))
        $normal_nodes
        Number of Special Node Reps: $(length(special_reps))
        $special_nodes
        """
    end

    return (
        classes = classes, 
        normal_reps = normal_reps,
        special_reps = special_reps,
    )
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
        pathindex = getindex(sa_node)
        # Get the component name in the original architecture
        path = sa.pathtable[address][pathindex]
        # Get the component from the architecture
        component = arch[path]
        if !canmap(A, m_node, component)
            push!(bad_nodes, index)
            @warn """
                Node index $m_node_name incorrectly assigned to architecture
                node $(path).
                """
        end
    end
    return bad_nodes
end
