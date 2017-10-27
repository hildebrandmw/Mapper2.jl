# TODO: Allow custom frameworks to declare their own routing primitives.
#   Need to really think about how to do that cleanly.

#=
A collection of routing semantics for various primitives.

Each primitive should return a LightGraph equivalent of the routing semantics
of the given object type. Furthermore, a dictionary should be supplied to
mapping ports names to vertices in the LightGraph to inform the graph creator
how to interface to the returned graph.
=#
struct RoutingGraph{P <: AbstractComponentPath, T <: Integer}
    graph   ::LightGraphs.SimpleGraphs.SimpleDiGraph{T}
    portmap ::Dict{PortPath{P}, T}
    linkmap ::Dict{LinkPath{P}, T}
    function RoutingGraph(graph,
                          portmap::Dict{PortPath{P}, T},
                          linkmap::Dict{LinkPath{P}, T}) where P where T
        #= Make sure that all of the values in the port map are valid.  =#
        num_vertices = nv(graph)
        for v in values(portmap)
            v <= num_vertices || error()
        end
        for v in values(linkmap)
            v <= num_vertices || error()
        end
        return new{P,T}(graph, portmap, linkmap)
    end
end

"""
    build_routing_mux(c::Component)

Return a RoutingGraph for a mux component. Consists of a single node. With
all ports going to or coming from the node.
"""
function build_routing_mux(c::Component)
    # Assert that this component has not children or intra-component routing
    assert_no_children(c)
    assert_no_intrarouting(c)
    # Build a light graph consisting of a single node.
    g = DiGraph(1)
    # Connect all input and outputs to the one node.
    portmap = Dict(PortPath(p) => 1 for p in keys(c.ports))
    linkmap = Dict{LinkPath{ComponentPath},eltype(g)}()
    return RoutingGraph(g, portmap, linkmap)
end

"""
    build_routing_blackbox(c::Component)

Return a RoutingGraph for a blackbox component. Consists of one node for
each top level port of the component and no edges. No vertices are created
for non-top level ports.
"""
function build_routing_blackbox(c::Component)
    # Get all of the ports for this component. 
    ports = keys(c.ports)
    # Instantiate the number of vertices equal to the number of ports.
    g = DiGraph(length(ports))
    # Sequentially assign port mappings.
    portmap = Dict(PortPath(p) => i for (i,p) in enumerate(ports))
    linkmap = Dict{LinkPath{ComponentPath},eltype(g)}()
    return RoutingGraph(g, portmap, linkmap)
end

const __ROUTING_DICT = Dict(
    "mux"   => build_routing_mux,
)

function routing_skeleton(c::Component)
    # Determine which constructor function to use on this component.
    f = get(__ROUTING_DICT, c.primitive, build_routing_blackbox)
    # Call the constructor function.
    return f(c)
end

function routing_skeleton(tl::TopLevel)
    path_type = AddressPath{dimension(tl)}
    # Return an empty graph
    graph = DiGraph(0)
    portmap = Dict{PortPath{path_type},eltype(graph)}()
    linkmap = Dict{LinkPath{path_type},eltype(graph)}()
    return RoutingGraph(graph, portmap, linkmap)
end

