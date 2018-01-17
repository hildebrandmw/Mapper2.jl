################################################################################
# LINK STATE structure
################################################################################

# Struct for recording which paths in the taskgraph are currently using the
# given resource.
struct LinkState
    values::Vector{Int64}
end
LinkState() = LinkState(Int64[])

Base.values(ls::LinkState) = ls.values
Base.push!(ls::LinkState, value...) = push!(ls.values, value...)
Base.delete!(ls::LinkState, value) = deleteat!(ls.values,findfirst(x -> x == value, ls.values))

getoccupancy(ls::LinkState) = length(ls.values)

################################################################################
# ROUTING LINKS
################################################################################

# Default link for recording the information about routing links.
struct RoutingLink <: AbstractRoutingLink
    state   ::LinkState
    cost    ::Float64
    capacity::Int64
end
RoutingLink(;cost = 1.0, capacity = 1) = RoutingLink(LinkState(), cost, capacity)

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
# LINK ANNOTATOR.
################################################################################
struct LinkAnnotator{T <: AbstractRoutingLink}
    links::Vector{T} 
end

const LA = LinkAnnotator


Base.setindex!(a::LA, l::AbstractRoutingLink, i::Integer) = a.links[i] = l
Base.getindex(a::LA, i::Integer) = a.links[i]
getlinks(a::LA) = a.links
nodecost(a::LA, i::Integer) = getcost(a[i])

function iscongested(a::LA)
    for link in getlinks(a)
        iscongested(link) && return true
    end
    return false
end
#-- iterator interface.
Base.start(a::LA)   = start(a.links)
Base.next(a::LA, s) = next(a.links, s)
Base.done(a::LA, s) = done(a.links, s)

################################################################################
# DEFAULT CONSTRUCTORS FOR ABSTRACT ARCHITECTURES
################################################################################
# Function definitions located in Routing.jl

# empty_annotator
# annotate_port
# annotate_link

################################################################################
# DEFAULT ANNOTATION FUNCTION
################################################################################
# TODO: add the actual ports and links to the function calls for annotation.
function annotate(arch::TopLevel{A}, rg::RoutingGraph) where A <: AbstractArchitecture
    DEBUG && print_with_color(:cyan, "Annotating Graph Links.\n")
    # Construct an empty annotator supplied by the framework declaring the
    # architecture A
    routing_links = Vector{routing_link_type(A)}(nv(rg.graph))
    # Iterate first through the ports of the routing graph, and then through
    # the links of the routing graph.
    portmap_rev = rev_dict_safe(rg.portmap)
    for (index,portpaths) in portmap_rev
        #=
        For now, we're going to assume that if "portpaths" has a length greater
        than 1 (meaning that multiple ports were condensed into 1), then it is
        the result of some overloading of the routing graph policy and we're 
        going to hand it over to a annotate_component function.
        =#
        ports = [arch[p] for p in portpaths]
        if length(ports) > 1
            # Get the prefix of the component
            component_path = prefix(first(portpaths))
            new_link = annotate_component(A, arch[component_path], ports)
        else
            new_link = annotate_port(A, first(ports))
        end
        routing_links[index] = new_link
    end
    linkmap_rev = rev_dict_safe(rg.linkmap)
    for (index,linkpaths) in linkmap_rev
        links = [arch[l] for l in linkpaths]
        new_link = annotate_link(A, first(links))
        routing_links[index] = new_link
    end
    return LinkAnnotator(routing_links)
end
