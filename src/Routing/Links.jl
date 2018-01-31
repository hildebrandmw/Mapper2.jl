################################################################################
# LINK STATE structure
################################################################################

# Struct for recording which paths in the taskgraph are currently using the
# given resource.

"""
    struct ChannelList

Data structure for recording the task indices that are using the given link.
"""
struct ChannelList
    channels::Vector{Int64}
end
ChannelList() = ChannelList(Int64[])

Base.values(c::ChannelList) = c.channels
Base.push!(c::ChannelList, value...) = push!(c.channels, value...)

function Base.delete!(c::ChannelList, value) 
    deleteat!(c.channels,findfirst(x -> x == value, c.channels))
end

Base.length(c::ChannelList) = length(c.channels)

################################################################################
# ROUTING LINKS
################################################################################

# Default link for recording the information about routing links.
struct RoutingLink <: AbstractRoutingLink
    channels::ChannelList
    cost    ::Float64
    capacity::Int64
end

RoutingLink(;cost = 1.0, capacity = 1) = RoutingLink(ChannelList(), cost, capacity)

# Accessor functions
channels(a::ARL)   = a.channels
cost(a::ARL)       = a.cost
capacity(a::ARL)   = a.capacity
occupancy(a::ARL)  = length(a.channels)

# Methods
iscongested(a::ARL) = occupancy(a) > capacity(a)
addchannel(a::ARL, channel) = push!(channels(a),   channel)
remchannel(a::ARL, channel) = delete!(channels(a), channel)

################################################################################
# LINK ANNOTATOR.
################################################################################
function iscongested(a::Vector{L}) where L <: AbstractRoutingLink
    for link in a
        iscongested(link) && return true
    end
    return false
end

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
    return routing_links
end
