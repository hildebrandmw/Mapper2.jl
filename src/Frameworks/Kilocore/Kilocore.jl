#=
Framework for the Kilocore project using the rest of the Mapper infrastructure.

Special methods for:

Architecture Creation
Taskgraph Construction
Placement Related Functions
Routing Related Functions

will be defined in this folder.
=#

################################################################################
# Attributes to determine what tasks may be mapped to which components in
# the architecture.
################################################################################

#=
Model for asap4
=#
const _kilocore_attributes = Set([
      "processor",
      "memory_processor",
      "fast_processor",
      "viterbi",
      "fft",
      "input_handler",
      "output_handler",
      "memory_1port",
      "memory_2port",
    ])

const _special_attributes = Set([
      "memory_processor",
      "fast_processor",
      "viterbi",
      "fft",
      "input_handler",
      "output_handler",
      "memory_1port",
      "memory_2port",
    ])


################################################################################
# Custrom Architecture used by this Framework
################################################################################

#=
Custom Abstract Architectures defined in this framework.
Both KiloCore and Asap4 will wall in the KCArchitecture type.
Principles of the type include:

- attributes for components that determine mapping.
=#
abstract type AbstractKC <: AbstractArchitecture end
"Basic architecture - no weights on links"
struct KCBasic <: AbstractKC end
"Basic architecture with link weights"
struct KCLink  <: AbstractKC end

include("asap4.jl")
include("asap3.jl")

# REQUIRED METHODS
"""
    ismappable(::AbstractKC, c::Component)

The default criteria for a component being a mappable component is that is must
have an "attributes" field in its metadata (value should be a vector of strings)
and the length of that vector should be greater than 0.
"""
function ismappable(::Type{T}, c::Component) where {T <: AbstractKC}
    return haskey(c.metadata, "attributes") && length(c.metadata["attributes"]) > 0
end

"""
    isspecial(::Type{T}, t::TaskgraphNode) where {T <: AbstractKC}

Return `true` if the taskgraph node requires a special attribute and thus
needs special consideration for placement.

Throw error if node is missing a "required_attributes" field in its metadata.
"""
function isspecial(::Type{T}, t::TaskgraphNode) where {T <: AbstractKC}
    return oneofin(t.metadata["required_attributes"], _special_attributes)
end

"""
    isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode) where {T <: AbstractKC}

Return `true` if taskgraph nodes `a` and `b` are considered "equivalent" when
it comes to placement.
"""
function isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode) where {T <: AbstractKC}
    # Return true if the "required_attributes" are equal
    return a.metadata["required_attributes"] == b.metadata["required_attributes"]
end

"""
    canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: AbstractKC}

Return `true` if taskgraph node `t` and be mapped to component `c`.
"""
function canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: AbstractKC}
    return issubset(t.metadata["required_attributes"], c.metadata["attributes"])
end

################################################################################
# Methods for architectures with link weights
################################################################################
struct CostSAEdge <: AbstractSAEdge
    sources ::Vector{Int64}
    sinks   ::Vector{Int64}
    cost    ::Float64
end

function build_sa_edge(::Type{KCLink}, edge::TaskgraphEdge, node_dict)
    # Build up adjacency lists.
    # Sources in the task-graphs are strings so we can just use the
    # node-dictionary to convert them into integers.
    sources = [node_dict[s] for s in edge.sources]
    sinks   = [node_dict[s] for s in edge.sinks]
    # Assign the cost of the link using the "weight" parameter added by
    # one of the earlier transforms to the taskgraph
    cost    = edge.metadata["weight"]
    return CostSAEdge(sources, sinks, cost)
end

# Costed metric functions
function edge_cost(::Type{KCLink}, sa::SAStruct, edge) 
    cost = 0.0
    for src in sa.edges[edge].sources, snk in sa.edges[edge].sinks
        # Get the source and sink addresses
        src_address = sa.nodes[src].address
        snk_address = sa.nodes[snk].address
        cost += sa.edges[edge].cost * sa.distance[src_address, snk_address]
    end
    return cost
end

################################################################################
# Taskgraph Constructors used by this framework.
################################################################################
struct SimDumpConstructor <: AbstractTaskgraphConstructor
    name::String
    file::String
    function SimDumpConstructor(appname)
        # Just copy the app name for the "name" portion of the constructor
        # Split it on any "." points and take the first argument.
        name = split(appname, ".")[1]
        # Check if appname ends in ".json.gz". If not, fix that
        appname = split(appname, ".")[1] * ".json.gz"
        # Append the sim dump file path to the beginning.
        file = joinpath(PKGDIR, "sim-dumps", appname)
        return new(name, file)
    end
end

include("taskgraph.jl")
