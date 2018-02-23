"""
Overwrite routing link type to allow classification of routing links by class.
"""
struct TypedRoutingLink <: AbstractRoutingLink
    channels::ChannelList
    cost    ::Float64
    capacity::Int64
    class   ::String
end

"""
Provide constructor.
"""
function TypedRoutingLink(cost, capacity, class)
    return TypedRoutingLink(ChannelList(), cost, capacity, class)
end

"""
Provide dispatch mechanism.
"""
Mapper2.routing_link_type(::Type{A}) where {A <: TestArchitecture} = TypedRoutingLink

"""
New RoutingTask type to allow classification of tasks by a class.
"""
struct TypedRoutingChannel <: AbstractRoutingChannel
    start::Vector{Int64}
    stop::Vector{Int64}
    class::String
    function TypedRoutingChannel(start, stop, edge)
        class = get(edge.metadata, "class", "all")
        return new(start, stop, class)
    end
end

"""
Routing Task dispatch mechanism.
"""
Mapper2.routing_channel_type(::Type{A}) where {A <: TestArchitecture} = TypedRoutingChannel

# Provide custom annotation methods.
function Mapper2.annotate_port(::Type{A},port) where {A <: TestArchitecture}
    capacity = get(port.metadata, "capacity", 10)
    class    = get(port.metadata, "class", "all")
    cost     = get(port.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate_link(::Type{A},link) where {A <: TestArchitecture}
    capacity = get(link.metadata, "capacity", 10)
    class    = get(link.metadata, "class", "all")
    cost     = get(link.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate_component(::Type{A}, component::Component, ports) where {A <: TestArchitecture}
    @assert component.primitive == "mux"
    return TypedRoutingLink(1.0,10,"all")
end

# Validity checks
function check_class(item, edge::TaskgraphEdge)
    item_class = get(item.metadata, "class", "all")
    edge_class = get(edge.metadata, "class", "all")
    return check_class(item_class, edge_class)
end
function check_class(item, edge)
    if edge == "all"
        return true
    elseif item == "all"
        return true
    else
        return edge == item
    end
end

function Mapper2.canuse(::Type{A}, item::Union{Port,Link}, edge::TaskgraphEdge) where
        A <: TestArchitecture
    return check_class(item, edge)
end
function Mapper2.canuse(::Type{A}, item::TypedRoutingLink, edge::TypedRoutingChannel) where
        A <: TestArchitecture
    return check_class(item.class, edge.class)
end
function Mapper2.isvalid_source_port(::Type{A}, 
                                     port::Port, 
                                     edge::TaskgraphEdge) where A <: TestArchitecture
    port.class in Mapper2.PORT_SINKS || return false
    # Check metadata
    return check_class(port, edge)
end
function Mapper2.isvalid_sink_port(::Type{A}, 
                                   port::Port, 
                                   edge::TaskgraphEdge) where A <: TestArchitecture
    port.class in Mapper2.PORT_SOURCES || return false
    # Check metadata
    return check_class(port, edge)
end
