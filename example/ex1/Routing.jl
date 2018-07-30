"""
Overwrite routing link type to allow classification of routing links by class.
"""
struct TypedRoutingLink <: RoutingLink
    channels::Vector{ChannelIndex}
    cost    ::Float64
    capacity::Int64
    class   ::String
end

"""
Provide constructor.
"""
function TypedRoutingLink(cost, capacity, class)
    return TypedRoutingLink(Int[], cost, capacity, class)
end


"""
New RoutingTask type to allow classification of tasks by a class.
"""
struct TypedRoutingChannel <: RoutingChannel
    start_vertices::Vector{PortVertices}
    stop_vertices::Vector{PortVertices}
    class::String

    function TypedRoutingChannel(start, stop, edge)
        class = get(edge.metadata, "class", "all")
        return new(start, stop, class)
    end
end

function Mapper2.routing_channel(::TestRuleSet, start, stop, edge::TaskgraphEdge)
    TypedRoutingChannel(start, stop, edge)
end
function Mapper2.getcapacity(::TestRuleSet, item)
    return get(item.metadata, "capacity", 10)
end

# Provide custom annotation methods.
function Mapper2.annotate(ruleset::TestRuleSet, port::Port)
    capacity = getcapacity(ruleset, port)
    class    = get(port.metadata, "class", "all")
    cost     = get(port.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate(ruleset::TestRuleSet, link::Link)
    capacity = getcapacity(ruleset, link)
    class    = get(link.metadata, "class", "all")
    cost     = get(link.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate(::TestRuleSet, component::Component)
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

Mapper2.canuse(::TestRuleSet, item::Union{Port,Link}, edge::TaskgraphEdge) = check_class(item, edge)
Mapper2.canuse(::TestRuleSet, item::TypedRoutingLink, edge::TypedRoutingChannel) = check_class(item.class, edge.class)

Mapper2.is_source_port(::TestRuleSet, port::Port, edge::TaskgraphEdge) = check_class(port, edge)
Mapper2.is_sink_port(::TestRuleSet, port::Port, edge::TaskgraphEdge) = check_class(port, edge)
