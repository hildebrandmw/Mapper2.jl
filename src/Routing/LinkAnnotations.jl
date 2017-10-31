################################################################################
# LINK STATE structure
################################################################################

# Struct for recording which paths in the taskgraph are currently using the
# given resource.
mutable struct LinkState
    values::Vector{Int64}
end
LinkState() = LinkState(Int64[])

Base.push!(ls::LinkState, value) = push!(ls.values, value)
Base.delete!(ls::LinkState, value) = deleteat!(ls.values,findfirst(x -> x == value, ls.values))

getoccupancy(ls::LinkState) = length(ls.values)

################################################################################
# ROUTING LINKS
################################################################################

# Default link for recording the information about routing links.
abstract type AbstractRoutingLink end
const ARL = AbstractRoutingLink
struct DefaultRoutingLink <: AbstractRoutingLink
    state   ::LinkState
    cost    ::Float64
    capacity::Int64
end
DefaultRoutingLink() = DefaultRoutingLink(LinkState(), 1.0, 1)

# Accessor functions
getstate(arl::ARL)      = arl.state
getcost(arl::ARL)       = arl.cost
getcapacity(arl::ARL)   = arl.capacity
getoccupancy(arl::ARL)  = getoccupancy(getstate(arl))

# Methods
iscongested(arl::ARL) = getoccupancy(getstate(arl)) > getcapacity(arl)
addlink(arl::ARL, link_index) = push!(getstate(arl), link_index)
remlink(arl::ARL, link_index) = delete!(getstate(arl), link_index)

################################################################################
# DEFAULT LINK ANNOTATOR.
################################################################################

# Abstract super types for all link annotators.
abstract type AbstractLinkAnnotator end
const ANA = AbstractLinkAnnotator

Base.setindex!(a::ANA, l::AbstractRoutingLink, i::Integer) = a.links[i] = l
Base.getindex(a::ANA, i::Integer) = a.links[i]
getlinks(a::ANA) = a.links
nodecost(a::ANA, i::Integer) = getcost(a[i])

function iscongested(a::ANA)
    for link in getlinks(a)
        iscongested(link) && return true
    end
    return false
end

struct DefaultLinkAnnotator{T <: AbstractRoutingLink} <: AbstractLinkAnnotator
    links::Vector{T} 
end


################################################################################
# DEFAULT CONSTRUCTORS FOR ABSTRACT ARCHITECTURES
################################################################################

# Default constructors.
function empty_annotator(::Type{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    links = Vector{DefaultRoutingLink}(nv(rg.graph))
    return DefaultLinkAnnotator(links)
end

function annotate_port(::Type{A}, 
                       annotator::B, 
                       ports, 
                       link_index) where {A <: AbstractArchitecture,
                                          B <: AbstractLinkAnnotator}
    annotator[link_index] = DefaultRoutingLink()
end

function annotate_link(::Type{A}, 
                       annotator::B, 
                       links, 
                       link_index) where {A <: AbstractArchitecture,
                                          B <: AbstractLinkAnnotator}
    annotator[link_index] = DefaultRoutingLink()
end

################################################################################
# DEFAULT ANNOTATION FUNCTION
################################################################################
function annotate(::Type{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    DEBUG && print_with_color(:cyan, "Annotating Graph Links.\n")
    # Construct an empty annotator supplied by the framework declaring the
    # architecture A
    link_annotator = empty_annotator(A, rg)
    # Iterate first through the ports of the routing graph, and then through
    # the links of the routing graph.
    portmap_rev = rev_dict_safe(rg.portmap)
    for (k,v) in portmap_rev
        annotate_port(A, link_annotator, v, k)
    end
    linkmap_rev = rev_dict_safe(rg.linkmap)
    for (k,v) in linkmap_rev
        annotate_link(A, link_annotator, v, k)
    end
    return link_annotator
end
