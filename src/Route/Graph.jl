const PPLC = Union{Path{Port},Path{Link},Path{Component}}

"""
Representation of the routing resources of a `TopLevel`.
"""
struct RoutingGraph

    """
    Adjacency information of routing resources, encode as a 
    `LightGraphs.SimpleDiGraph`.
    """
    graph :: SimpleDiGraph{Int64}

    """
    Translation information mapping elements on the parent `TopLevel` to indices
    in `graph`.

    Implemented as a `Dict{Path{<:Union{Port,Link,Component}}, Int64}` where the
    values in the dict are the vertex index in `graph` of the key.
    """
    map :: Dict{PPLC, Int64}

    function RoutingGraph(graph::AbstractGraph, map::Dict{P,Int64}) where {P <: Path}

        #= Make sure that all of the values in the port map are valid. =#
        num_vertices = nv(graph)
        for v in values(map)
            if v > num_vertices 
                error("Map value $v greater than number of vertices: $(nv(graph))")
            end
        end
        m = Dict{PPLC,Int}(map)
        return new(graph, m)
    end
end

"""
Return the `map` of a [`RoutingGraph`](@ref)

Method List
-----------
$(METHODLIST)
"""
getmap(graph::RoutingGraph) = graph.map

function translate_routes(r::RoutingGraph, graphs::Vector{<:SparseDiGraph})
    map_reversed = rev_dict(r.map)

    routes = map(graphs) do g
        route = SparseDiGraph{PPLC}()
        # Add vertices
        for v in vertices(g)
            path = map_reversed[v]
            add_vertex!(route, path)
        end
        # Add edges
        for src in vertices(g), dst in outneighbors(g, src)
            add_edge!(route, map_reversed[src], map_reversed[dst])
        end

        return route
    end

    return routes
end


# Make a vertex for each port and a single vertex in the middle.
# Connect all inputs with an edge input -> middle
#
# Connect all outputs with an edge middle -> output
function build_routing_mux(c::Component)
    # Assert that this component has not children or intra-component routing
    assert_no_children(c)
    assert_no_intrarouting(c)

    g = DiGraph(length(c.ports) + 1)
    # Create a path for node #1, the node in the middle of the mux
    m = Dict{Path,Int}(Path{Component}() => 1)

    for (i,(p,v)) in enumerate(c.ports)
        # Add 1 to i to account for the Path{Component}() we already added.
        node_index = i+1
        m[Path{Port}(p)] = node_index

        if v.class == Output
            add_edge!(g, 1, node_index)
        elseif v.class == Input
            add_edge!(g, node_index, 1)
        else
            throw(KeyError(v.class))
        end
    end

    return RoutingGraph(g,m)
end

# Create a graph with vertices for each port and no edges.
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

function routing_skeleton(tl::TopLevel)
    # Return an empty graph
    g = DiGraph(0)
    m = Dict{Path,Int}()
    return RoutingGraph(g,m)
end

function record!(new_dict::Dict, old_dict::Dict, offset::Integer, extension)
    for (path,index) in old_dict
        # Update path
        new_path = catpath(extension, path)
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
        for edge in edges(subgraph.graph)
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

function splicegraphs(
        component::AbstractComponent, 
        topgraph::RoutingGraph, 
        subgraphs
    )

    add_subgraphs!(topgraph, keys(component.children), subgraphs)
    add_links!(topgraph, component)
    return topgraph
end

function routing_graph(
        component::AbstractComponent, 
        memoize = true,
        memo = Dict{String, RoutingGraph}()
    )

    # Check if the graph for this component has been memoized and return the
    # memoized result if it has.
    if memoize && haskey(memo, component.name) 
        return memo[component.name]
    end

    # If this component has not children, no need to route each of the children,
    # just build a routing skeleton for it.
    if length(component.children) == 0
        graph = routing_skeleton(component)

    # Recursively build graphs for each of the children of this component.
    # Once all the graphs for the children have been created, splice them into
    # a skeleton graph for this component.
    else
        subgraphs = [routing_graph(i,memoize,memo) for i in children(component)]
        topgraph  = routing_skeleton(component)
        graph = splicegraphs(component, topgraph, subgraphs)
    end
    # Memoize this result
    memoize && memoize!(component, memo, component.name, graph)
    safety_check(component, graph)
    return graph
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
