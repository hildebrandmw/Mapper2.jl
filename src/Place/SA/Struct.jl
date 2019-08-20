################################################################################
# Abstract Types for Placement
################################################################################

##########
# SANode #
##########

"""
Abstract super types for the `SA` representation of `TaskgraphNodes`.

API
---
* [`location`](@ref)
* [`assign`](@ref)
* [`getclass`](@ref)
* [`setclass!`](@ref)

Implementations
---------------
* [`BasicNode`](@ref)
"""
abstract type SANode end

# API
"""
    location(node::SANode{T}) :: T

Return the location of `node`. Must be parameterized by `T`.
"""
function location end

"""
    assign(node::SANode{T}, location::T)

Set the location of `node` to `location`.
"""
function assign end

"""
    getclass(node)

Return the class of `node`.
"""
function getclass end

"""
    setclass!(node, class::Integer)

Set the class of `node` to `class`.
"""
function setclass! end

#############
# SAChannel #
#############
"""
[`SAStruct`](@ref) representation of a [`TaskgraphEdge`](@ref). Comes in two
varieties: [`TwoChannel`](@ref) and [`MultiChannel`](@ref)
"""
abstract type SAChannel end

"""
Abstract supertype for channels with only one source and sink.

Required Fields
---------------
* `source::Int64`
* `sink::Int64`

Implementations
---------------
* [`BasicChannel`](@ref)
"""
abstract type TwoChannel <: SAChannel end

"""
Abstract supertype for channels with multiple sources/sinks.

Required Fields
---------------
* `sources::Vector{Int}`
* `sinks::Vector{Int}`

Implementations
---------------
* [`BasicMultiChannel`](@ref)
"""
abstract type MultiChannel <: SAChannel end

###############
# AddressData #
###############

"""
Supertype for containers of data for address specific placement. There is no
API for this type since the specific needs of address data vary between
applications. If a custom type is used, extend [`address_cost`] to get the
desired behavior.

Implementations
---------------
* [`EmptyAddressData`](@ref)
* [`DefaultAddressData`](@ref)
"""
abstract type AddressData end


"""
Null representation of [`AddressData`](@ref). Used when there is no address
data to be used during placement.
"""
struct EmptyAddressData <: AddressData end


"""
Default implementation of address data when it is to be used. In its normal
state, it is just a wrapper for a `Dict` mapping addresses to a cost. Look
at the implementation of [`address_cost`](@ref) to see how this is used. This
function may be exteneded on `node` to provide different behavior.

To use this type, the method [`address_data`](@ref) must be defined to
encode the values for the dict.
"""
struct DefaultAddressData{U,T} <: AddressData
    dict :: Dict{U,T}
end

getindex(A::DefaultAddressData{U}, i::U) where U = getindex(A.dict, i)

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
        T <: RuleSet,
        U <: SADistance,
        D,
        N <: SANode,
        L <: SAChannel,
        M <: AbstractMapTable,
        A <: AddressData,
        Q
    }

    ruleset::T

    "`Vector{N}`: Container of nodes."
    nodes :: Vector{N}
    "`Vector{L}`: Container of edges."
    channels :: Vector{L}
    maptable :: M
    distance :: U
    grid :: Array{Int64,D}
    address_data :: A
    aux :: Q
    # Map back fields
    pathtable :: PathTable{D,Path{Component}}
    tasktable :: Dict{String,Int64}
end

# Convenience decoding methods
dimension(::SAStruct{T,U,D})  where {T,U,D} = D
MapperCore.rules(sa_struct::SAStruct) = sa_struct.ruleset
nodetype(s::SAStruct) = typeof(s.nodes)
channeltype(s::SAStruct) = typeof(s.channels)
distancetype(::SAStruct{T,U}) where {T,U} = U

isflat(x) = false
isflat(::SAStruct{A,U,D,D}) where {A,U,D} = true
Base.eltype(sa_struct::SAStruct) = location_type(sa_struct.maptable)

################################################################################
# Basis SA Node
################################################################################

"""
The standard implementation of [`SANode`](@ref).
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
@inline location(x::CartesianIndex)   = x
@inline assign(n::SANode, l)          = (n.location = l)
@inline getclass(n::SANode)           = n.class
@inline setclass!(n::SANode, class)   = n.class = class

isnormal(node::SANode) = isnormal(class(node))
isnormal(class::Int64) = class > 0

# -------------
# Construction
# -------------
function buildnode(::RuleSet, n::TaskgraphNode, x)
    return BasicNode(x, 0, Int64[], Int64[])
end

"""
    setup_node_build(ruleset, taskgraph, location_type)
"""
function setup_node_build(ruleset::RuleSet, t::Taskgraph, ::PathTable{D}) where D
    return [buildnode(ruleset, n, zero(Address{D})) for n in getnodes(t)]
end

################################################################################
# Basis SA Edge
################################################################################

"Basic Implementation of [`TwoChannel`](@ref)"
struct BasicChannel <: TwoChannel
    source::Int64
    sink  ::Int64
end

"Basic Implementation of [`MultiChannel`](@ref)"
struct BasicMultiChannel <: MultiChannel
    sources ::Vector{Int64}
    sinks   ::Vector{Int64}
end

function setup_channel_build(ruleset::RuleSet, taskgraph)
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
    return build_channels(ruleset, edges, sources, sinks)
end

function build_channels(ruleset::RuleSet, edges, sources, sinks)
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

# Document the "address_data" that users must provide to opt-in to address
# specific data generation.

"""
    address_data(ruleset::RuleSet, component::Component) :: T where T

Return some token representing address specific data for `component` under
`ruleset`.
"""
function address_data end

# Default to assigning zero(Float64) to all addresses
address_data(ruleset::RuleSet, component::Component) = zero(Float64)

function build_address_data(
        ruleset::RuleSet,
        toplevel::TopLevel{D},
        pathtable;
        isflat = false
    ) where D

    data(address) = [address_data(ruleset, toplevel[path]) for path in pathtable[address]]
    address_data = Dict(
        addr => data(addr)
        for addr in CartesianIndices(pathtable)
        if length(pathtable[addr]) > 0
    )
    # If the flat optimization is turned on - remove the vectors from the values
    # in the dictionary.
    if isflat
        return Dict(k => first(v) for (k,v) in address_data)
    else
        return address_data
    end
end


################################################################################
# Constructor for the SA Structure
################################################################################
function SAStruct(
        m :: Map{D};
        # Enable address-specific data.
        enable_address = false,
        aux = nothing,
        kwargs...
    ) where {D}

    #@debug "Building SA Placement Structure\n"

    # Unpack some data structures for easier reference.
    toplevel = m.toplevel
    taskgraph = m.taskgraph
    ruleset = rules(m)

    pathtable = build_pathtable(toplevel, ruleset)

    # TODO: Make extendable.
    distance = BasicDistance(toplevel, pathtable)

    # Build SA Node types and make a record mapping node name to the index of
    # that nodes representation in this data structure.
    nodes = setup_node_build(rules(m), taskgraph, pathtable)
    tasktable = Dict(n.name => i for (i,n) in enumerate(getnodes(taskgraph)))

    # Build Channel
    channels = setup_channel_build(rules(m), taskgraph)
    @debug """
        Node Type: $(typeof(nodes))
        Edge Type: $(typeof(channels))
        """

    # Assign adjacency information to nodes.
    record_channels!(nodes, channels)

    #----------------------------------------------------#
    # Obtain task equivalence classes from the taskgraph #
    #----------------------------------------------------#
    #equivalence_classes = task_equivalence_classes(taskgraph, rules(m))
    # Create function wrapper for "isequivalent"
    f = (x,y) -> isequivalent(rules(m), x, y)
    classes = equivalence_classes(f, getnodes(taskgraph))

    # Assign each node with its given classification.
    for (index, class) in enumerate(classes.classes)
        setclass!(nodes[index], class)
    end

    maptable = MapTable(toplevel, rules(m), classes, pathtable)
    grid = zeros(size(pathtable)...)

    if enable_address
        address_data = build_address_data(rules(m), toplevel, pathtable, isflat = isflat)
    else
        address_data = EmptyAddressData()
    end

    sa = SAStruct{
        typeof(rules(m)),     # RuleSet Type
        typeof(distance),     # Encoding of Tile Distance
        ndims(grid),          # Architecture Dimensionality + 1
        eltype(nodes),        # Type of the taskgraph nodes
        eltype(channels),     # Type of the taskgraph channels
        typeof(maptable),
        typeof(address_data),  # Type of address data
        typeof(aux),
     }(
        rules(m),
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

cleargrid(sa::SAStruct) = clear(sa.grid)
clear(x::Array{T}) where T = x .= zero(T)

function preplace(m::Map, sa::SAStruct)
    cleargrid(sa)

    offset = getoffset(m.toplevel)
    for (taskname, path) in m.mapping.nodes
        address = getaddress(m.toplevel, path) + offset
        location = findaddress(sa.pathtable, address, path)
        # Get the index to assign
        index = sa.tasktable[taskname]
        # Assign the nodes
        assign(sa, index, location)
    end
    return nothing
end

################################################################################
# Write back method
################################################################################
function record(m::Map, sa::SAStruct)
    verify_placement(m, sa)
    mapping = m.mapping
    tasktable_rev = rev_dict(sa.tasktable)

    for (index, node) in enumerate(sa.nodes)
        # Get the mapping for the node
        address   = location(node)
        # Get the component name in the original toplevel
        path = sa.pathtable[address]
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

function equivalence_classes(f::Function, iter)
    classes = zeros(Int, length(iter))
    reps = eltype(iter)[]
    for (index, item) in enumerate(iter)
        # See if this item class has already been discovered.
        i = findfirst(x -> f(x, item), reps)
        # If not, add this item to the vector of representatives.
        if i == nothing
            push!(reps, item)
            i = length(reps)
        end
        # Record class
        classes[index] = i
    end
    return (
        classes = classes,
        reps = reps
    )
end


################################################################################
# Verification routine for SA Placement
################################################################################
function verify_placement(m::Map, sa::SAStruct)
    # Assert that the SAStruct belongs to the same toplevel
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

function check_mapability(m::Map, sa::SAStruct)
    bad_nodes = Int64[]
    toplevel = m.toplevel
    # Iterate through each node in the SA
    for (index, (m_node_name, m_node)) in enumerate(m.taskgraph.nodes)
        sa_node = sa.nodes[index]
        # Get the mapping for the node
        address = location(sa_node)
        #pathindex = getindex(sa_node)
        # Get the component name in the original toplevel
        path = sa.pathtable[address]
        # Get the component from the toplevel
        component = toplevel[path]
        if !canmap(rules(m), m_node, component)
            push!(bad_nodes, index)
            @warn """
                Node index $m_node_name incorrectly assigned to toplevel
                node $(path).
                """
        end
    end
    return bad_nodes
end
