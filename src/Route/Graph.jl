struct RoutingGraph{G}
    graph   ::G
    map     ::Dict{Path, Int64}
    function RoutingGraph{G}(graph::G, map::Dict{P,Int64}) where {G,P <: Path}

        #= Make sure that all of the values in the port map are valid. =#
        num_vertices = nv(graph)
        for v in values(map)
            if v > num_vertices 
                error("Map value $v greater than number of vertices: $(nv(graph))")
            end
        end
        m = Dict{Path,Int}(map)
        return new{G}(graph, m)
    end
end

RoutingGraph(g::G, m::Dict{P,Int64}) where {G,P <: Path} = RoutingGraph{G}(g,m)
getmap(r::RoutingGraph) = r.map

"""
    build_routing_mux(c::Component)

Return a RoutingGraph for a mux component. Consists of all ports and a single
node inside. Path for the inside nodes points to the component `c` in the
original architecture.
"""
function build_routing_mux(c::Component)
    # Assert that this component has not children or intra-component routing
    assert_no_children(c)
    assert_no_intrarouting(c)

    g = DiGraph(length(c.ports) + 1)
    # Create a path for node #1, the node in the middle of the mux
    m = Dict{Path,Int}(Path{Component}() => 1)

    for (i,(p,v)) in enumerate(c.ports)
        m[Path{Port}(p)] = i+1 

        if v.class == :output
            add_edge!(g, 1, i+1)
        elseif v.class == :input
            add_edge!(g, i+1, 1)
        else
            throw(KeyError(v.class))
        end
    end

    return RoutingGraph(g,m)
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
    if length(ports) == 0
        m = Dict{Path,Int}()
    else
        m = Dict{Path,Int}(Path{Port}(p) => i for (i,p) in enumerate(ports))
    end
    return RoutingGraph(g,m)
end

const __ROUTING_DICT = Dict(
    "mux" => build_routing_mux,
)

# Constructor dispatch based on primitive type. Default to BlackBox
function routing_skeleton(c::Component)
    f = get(__ROUTING_DICT, c.primitive, build_routing_blackbox)
    return f(c)
end

function routing_skeleton(tl::TopLevel{A,D}) where {A,D}
    # Return an empty graph
    g = DiGraph(0)
    m = Dict{Path,Int}()
    return RoutingGraph(g,m)
end

function record!(new_dict::Dict, old_dict::Dict, offset::Integer, extension)
    for (path,index) in old_dict
        # Update path
        new_path  = catpath(extension, path)
        # Update index
        new_index = index + offset
        # Record the new item.
        haskey(new_dict, new_path) && error()
        new_dict[new_path] = new_index
    end
end

function add_subgraphs!(top::RoutingGraph, prefixes, subgraphs::Vector{<:RoutingGraph})
    # Iterate through the prefixes and subgraphs.
    for (prefix, subgraph) in zip(prefixes, subgraphs)
        # Get an offset calculated by the number of vertices in the current graph.
        offset = nv(top.graph) 
        # Add the number of vertices in the subgraph to g.
        add_vertices!(top.graph, nv(subgraph.graph))
        # Create dictionary records for each of the new nodes.
        record!(top.map, subgraph.map, offset, prefix)
        # Record all the edges from the subgraph - account for offset.
        for edge in LightGraphs.edges(subgraph.graph)
            add_edge!(top.graph, src(edge) + offset, dst(edge) + offset)
        end
    end
    return nothing
end

function add_links!(top, c::AbstractComponent)
    # Iterate through all links for the component.
    for (key,link) in c.links
        # Create a node for the link
        add_vertex!(top.graph)
        link_index = nv(top.graph)
        # Create an entry in the link table
        linkpath = Path{Link}(key)
        top.map[linkpath] = link_index
        # Connect the link to all its attached ports by looking through the
        # PortPaths in the link and getting the reference vertex in the graph
        # from the portmap
        for port in sources(link)
            src = top.map[port]
            add_edge!(top.graph, src, link_index)
        end
        for port in dests(link)
            dst = top.map[port]
            add_edge!(top.graph, link_index, dst)
        end
    end
    return nothing
end

function splicegraphs(c::AbstractComponent, top::RoutingGraph, subgraphs::Vector)
    add_subgraphs!(top, keys(c.children), subgraphs)
    add_links!(top, c)
    return top
end

function routing_graph(c::AbstractComponent, 
                       memoize = true,
                       md = Dict{String, RoutingGraph}())

    # Check memoize dict
    memoize && haskey(md, c.name) && return md[c.name]
    if length(c.children) == 0
        g = routing_skeleton(c)
    else
        subgraphs = [routing_graph(i,memoize,md) for i in children(c)]
        topgraph  = routing_skeleton(c)
        g = splicegraphs(c, topgraph, subgraphs)
    end
    # Memoize this result
    memoize && memoize!(c, md, c.name, g)
    safety_check(c, g)
    return g
end

memoize!(::Component, md::Dict, key, value) = (md[key] = value)
memoize!(::TopLevel, md::Dict, key, value)  = nothing

safety_check(::Component, g) = nothing
function safety_check(::TopLevel, g) 
    maprev = rev_dict_safe(g.map)
    for (k,v) in maprev
        length(v) > 1 && throw(ErrorException("$k => $v"))
    end
    @debug routing_graph_info(g)
end

function routing_graph_info(g)
    """
    Number of Vertices: $(nv(g.graph))
    Number of Edges: $(ne(g.graph))
    Entries in Map Dictionary: $(length(g.map))
    """
end
