#=
A collection of routing semantics for various primitives.

Each primitive should return a LightGraph equivalent of the routing semantics
of the given object type. Furthermore, a dictionary should be supplied to
mapping ports names to vertices in the LightGraph to inform the graph creator
how to interface to the returned graph.
=#

const GRAPH_INT_TYPE = Int64
struct RoutingGraph{P <: AbstractComponentPath}
    graph   ::LightGraphs.SimpleGraphs.SimpleDiGraph{GRAPH_INT_TYPE}
    portmap ::Dict{PortPath{P}, GRAPH_INT_TYPE}
    linkmap ::Dict{LinkPath{P}, GRAPH_INT_TYPE}
    function RoutingGraph(graph,
                          portmap::Dict{PortPath{P}, GRAPH_INT_TYPE},
                          linkmap::Dict{LinkPath{P}, GRAPH_INT_TYPE}) where P

        #= Make sure that all of the values in the port map are valid. =#
        num_vertices = nv(graph)
        for v in values(portmap)
            v <= num_vertices || error()
        end
        for v in values(linkmap)
            v <= num_vertices || error()
        end
        return new{P}(graph, portmap, linkmap)
    end
end

#-- Overload the getindex function for reasonable behavior.
Base.getindex(rg::RoutingGraph, p::PortPath) = rg.portmap[p]
Base.getindex(rg::RoutingGraph, p::LinkPath) = rg.linkmap[p]

portmap(rg::RoutingGraph) = rg.portmap
linkmap(rg::RoutingGraph) = rg.linkmap

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

function routing_skeleton(c::Component)::RoutingGraph{ComponentPath}
    # Determine which constructor function to use on this component.
    f = get(__ROUTING_DICT, c.primitive, build_routing_blackbox)
    # Call the constructor function.
    return f(c)
end

function routing_skeleton(tl::TopLevel{A,D}) where {A,D}
    path_type = AddressPath{D}
    # Return an empty graph
    graph = DiGraph(0)
    portmap = Dict{PortPath{path_type},eltype(graph)}()
    linkmap = Dict{LinkPath{path_type},eltype(graph)}()
    return RoutingGraph(graph, portmap, linkmap)
end


#=
The base routing resources graph. Will store the routing resources graph
as a simple light graph and store conversion data to allow the graph to be
translated back to the original Map.
=#

#=
Need to do the following:

- Identify all special routing resources such as switches, muxes, and crossbars
    to allow efficient entering of these in the routing graph.

    TODO: Figure out how to represent these components so it's possible to
        add further, more specialized routing resources if that ever becomes
        required.

        PLAN:
        I'm thinking initially that a function will have to be
        implemented that will return a LightGraph equivalent of what the inserted
        routing resource will have to be. Will also have to yield information
        on how to hook up ports.

- Gather all ports in the whole top level recursively. Should return a giant
    vector of Addressed PortPaths.

    Can either immediately start building the graph from these nodes or do
    something like a BFS on the original architecture. The advantage of the former
    is that it will likely be easier. The latter might give slightly better
    performance by keeping related components close in index in the underlying
    light graph. However, this benefit will probably be gone after traveling
    through the first few levels.

    For now - go with the first. Write all down-stream code to not particularly
    care about the exact order so we can play with the ordering and see if that
    affects performance at all. (Probably not going to happen)

- With all the ports gathered, building links will probably be pretty easy.

- Whenever a node is entered into the routing resources graph, will have to make
    an entry in a tracking dictionary to make sure we can go back and forth from
    the underlying architecture and the routing resources graph. Also need a way
    of recording aspects about the routing resources like capacity, cost etc.

    Will probably take the same approach as placement and make it architecture
    based to allow slick overloading and replacement.
=#

function record!(new_dict::Dict, old_dict::Dict, offset::Integer, path_extension)
    # Iterate through the key value pairs of the old dictionary (usually a
    # portmap or linkmap.
    #
    # If this is the case, keys will be paths and values will be node indices.
    for (path,graph_index) in old_dict
        # Create a new path type from the old path type and the extension.
        # If the "extension" is a Address, will automatically promote path
        # from a "ComponentPath" to an "AddressPath"
        new_path  = pushfirst(path, path_extension)
        # Correct for the offset generated by splicing in the sub graph.
        new_index = graph_index + offset
        # If the new_path already lives in the top level dictionary - throw
        # an error.
        haskey(new_dict, new_path) && error()
        # Record the new item.
        new_dict[new_path] = new_index
    end
    return nothing
end

function add_subgraphs!(top::RoutingGraph, prefixes, subgraphs::Vector{<:RoutingGraph})
    # Iterate through the prefixes and subgraphs.
    for (prefix, subgraph) in zip(prefixes, subgraphs)
        # Get an offset calculated by the number of vertices in the current graph.
        offset = nv(top.graph) 
        # Add the number of vertices in the subgraph to g.
        add_vertices!(top.graph, nv(subgraph.graph))
        # Create dictionary records for each of the new nodes.
        record!(top.portmap, subgraph.portmap, offset, prefix)
        record!(top.linkmap, subgraph.linkmap, offset, prefix)
        # Record all the edges from the subgraph - account for offset.
        for edge in LightGraphs.edges(subgraph.graph)
            add_edge!(top.graph, src(edge) + offset, dst(edge) + offset)
        end
    end
    return nothing
end

make_link_path(::AbstractComponent, str) = LinkPath(str)
make_link_path(::TopLevel{A,D}, str) where {A,D} = LinkPath(str, zero(CartesianIndex{D}))

function add_links!(top, c::AbstractComponent)
    # Iterate through all links for the component.
    for (key,link) in c.links
        # Create a node for the link
        add_vertex!(top.graph)
        link_index = nv(top.graph)
        # Create an entry in the link table
        linkpath = make_link_path(c, key)
        top.linkmap[linkpath] = link_index
        # Connect the link to all its attached ports by looking through the
        # PortPaths in the link and getting the reference vertex in the graph
        # from the portmap
        for port in link.sources
            src = top.portmap[port]
            add_edge!(top.graph, src, link_index)
        end
        for port in link.sinks
            dst = top.portmap[port]
            add_edge!(top.graph, link_index, dst)
        end
    end
    return nothing
end

function splicegraphs(c::AbstractComponent, top, subgraphs::Vector{T}) where T
    #=
    Splice the subgraphs into the top level graph. Give the keys of thie
    children dictionary as prefixes for correctly promoting the
    port and link maps in the subgraphs.
    
    Will automatically update the mapping dictionaries and promote 
    ComponentPaths to AddressPaths if the given component `c` is the Top Level.
    =#
    add_subgraphs!(top, keys(c.children), subgraphs)
    # Add all edges at this level of hierarchy.
    add_links!(top, c)
    # Return finalized graph.
    return top
end

function routing_graph(c::AbstractComponent, 
                       memoize = true,
                       md = Dict{String, RoutingGraph{ComponentPath}}())

    # Check to see if this component is memoized. If so - just return the
    # memoized graph
    memoize && haskey(md, c.name) && return md[c.name]
    if length(c.children) == 0
        g = routing_skeleton(c)
    else
        # Call routing graph on each of the children of the component - will
        # recursively build up an array of completed component.
        subgraphs = [routing_graph(i,memoize,md) for i in children(c)]
        # Build the skeleton for the current top level component.
        topgraph = routing_skeleton(c)
        # Add all the routing at this level and splice all the independent graphs
        # of the subcomponents together.
        g = splicegraphs(c, topgraph, subgraphs)
    end
    # Memoize this result
    memoize && memoize!(c, md, c.name, g)
    return g
end

memoize!(::Component, md::Dict, key, value) = (md[key] = value)
memoize!(::TopLevel, md::Dict, key, value)  = nothing

function routing_graph_info(g)
    """
    Number of Vertices: $(nv(g.graph))
    Number of Edges: $(ne(g.graph))
    Entries in PortMap Dictionary: $(length(g.portmap))
    Entries in LinkMap Dictionary: $(length(g.linkmap))
    """
end
