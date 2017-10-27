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

function record!(new_dict::Dict, old_dict::Dict, offset::Integer, header)
    for (k,v) in old_dict
        new_k = unshift(k, header)
        new_v = v + offset
        haskey(new_dict, new_k) && error()
        new_dict[new_k] = new_v
    end
    return nothing
end

# TODO - cleanup
LinkPath(::Component, path) = LinkPath(path)
LinkPath(::TopLevel{A,D}, path) where {A,D} = LinkPath(path, Address{D}())

function splicegraphs(c::AbstractComponent, g, subgraphs)
    #=
    We'll grow the top graphs by adding sub components.
    Need to do the following:
        1. Determine the number of nodes currently in the top graph.
        2. Make an offset number for each sub-graph.
        3. Augment the port path keys of the dictionary to keep paths consistent.
    =#
    #=
    Create the base graph from the topgraph. In the case of the TopLevel,
    this will convert the portmap dictionary in the RoutingGraph to be of
    type AddressPath instead of ComponentPath.
    
    In the case of a normal component, will just return the topgraph.
    =#
    # Iterate through each child. Iterate through the dictionary of children
    # to correctly augment the PortPaths.
    for (child_entry, subgraph) in zip(keys(c.children), subgraphs)
        # Get an offset calculated by the number of vertices in the current graph.
        offset = nv(g.graph) 
        # Add the number of vertices in the subgraph to g.
        add_vertices!(g.graph, nv(subgraph.graph))
        # Create dictionary records for each of the new nodes.
        record!(g.portmap, subgraph.portmap, offset, child_entry)
        record!(g.linkmap, subgraph.linkmap, offset, child_entry)
        # Record all the edges from the subgraph.
        for edge in LightGraphs.edges(subgraph.graph)
            add_edge!(g.graph, edge.src + offset, edge.dst + offset)
        end
    end
    #=
    Finally - add all edges at this level of hierarchy.
    =#
    for (k,link) in c.links
        # Create a node for the link
        add_vertex!(g.graph)
        link_index = nv(g.graph)
        # Create an entry in the link table
        linkpath = LinkPath(c, k)
        g.linkmap[linkpath] = link_index
        # Connect the link to all its attached ports by looking through the
        # PortPaths in the link and getting the reference vertex in the graph
        # from the portmap
        for port in link.sources
            src = g.portmap[port]
            add_edge!(g.graph, src, link_index)
        end
        for port in link.sinks
            dst = g.portmap[port]
            add_edge!(g.graph, link_index, dst)
        end
    end
    return g
end

# Can optionally turn on memoization
function routing_graph(c::AbstractComponent, 
                       memoize = true,
                       md = Dict{String, RoutingGraph}())::RoutingGraph

    # Check to see if this component is memoized. If so - just return the
    # memoized graph
    memoize && haskey(md, c.name) && return md[c.name]

    # Call routing graph on each of the children of the component - will
    # recursively build up an array of completed component.
    subgraphs = [routing_graph(i,memoize,md) for i in children(c)]
    # Build the skeleton for the current top level component.
    topgraph = routing_skeleton(c)
    # Add all the routing at this level and splice all the independent graphs
    # of the subcomponents together.
    g = splicegraphs(c, topgraph, subgraphs)

    # Memoize this result
    memoize && (md[c.name] = g)
    return g
end
