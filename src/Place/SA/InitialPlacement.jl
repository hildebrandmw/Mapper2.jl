#=
Authors:
    Arthur Hlaing
    Mark Hildebrand

Provides a Bipartite matching routine to do initial placement of a taskgraph
to an placement structure.
=#

function initial_placement!(placement_struct)
    # Build graph
    graph, node_dict, component_dict = build_graph(placement_struct)
    # Run Bipartite Matching
    bipartite_match!(graph)
    @debug "Bipartite Matching Complete"
    do_assignment(placement_struct, graph, node_dict, component_dict)
    return graph
end

function build_graph(sa::SAStruct)
    #=
    Build translation tables.
    - Tasks will be mapped to vertices with an index number 2 higher than their
    index in the SAstruct. (vertices 1 and 2 are reserved for source and sink)
    - Will need to build a dictionary mapping tuples (Address, component_id) to
    an integer to keep track of architecture components.
    =#
    # Unpack commonly used object.
    component_table = sa.component_table

    # Offset for the source and sink nodes.
    sourcesink_offset = 2
    # Create the node translation dictionary
    node_dict = Dict(i => i + sourcesink_offset for i in 1:length(sa.nodes))
    # Start enumerating all the mapable components and building a translation
    # dictionary.
    keytype = Tuple{CartesianIndex{dimension(sa)},Int64}
    component_dict = Dict{keytype, Int64}()
    # Variable for keeping track of the current vertex number.
    vertex_number = sourcesink_offset + length(node_dict)
    for index in eachindex(component_table)
        # Check to see if the component list at this index is empty. If so,
        # move to the next index.
        length(component_table[index]) == 0 && continue
        # Convert the index into subscripts
        subscripts = ind2sub(component_table, index)
        # Create an address
        address = CartesianIndex(subscripts)
        # Iterate through all indices at this location.
        for i in 1:length(component_table[index])
            # Increment vertex cound
            vertex_number += 1
            # Create a key entry.
            key = (address, i)
            component_dict[key] = vertex_number
        end
    end
    # Build the light graph
    graph = DiGraph(vertex_number)
    edges_added = 0
    # Begin adding edges to the graph - get all of the unique equivalence classes.
    unique_classes = unique(sa.nodeclass)
    for class in unique_classes
        # Get all the node indices that fall into this class.
        node_indices = find(x -> x == class, sa.nodeclass)
        # Get the map table for this class.
        maptable = class < 0 ? sa.special_maptables[-class] : sa.maptables[class]
        # Iterate through all addresses - add an edge as appropriate.
        for index in eachindex(maptable)
            # Skip entries that have no component that this node class can
            # be mapped to.
            length(maptable[index]) == 0 && continue
            # Get the address
            address = CartesianIndex(ind2sub(maptable, index))
            # Iterate through all components this node class can be mapped
            # to at this address
            for i in 1:length(maptable[index])
                # Create a key to get the index of the component.
                # Key is a tuple (address, component_index)
                key = (address, Int64(maptable[index][i]))
                # Look up the node number from the component dict
                component_number = component_dict[key]
                # Create an edge for all nodes in the class.
                for node_index in node_indices
                    node_number = node_dict[node_index]
                    add_edge!(graph, node_number, component_number)
                    # Record the total number of edges added
                    edges_added += 1
                end
            end
        end
    end
    # Create the source and sink edges
    for i in values(node_dict)
        add_edge!(graph, 1, i)
    end
    for i in values(component_dict)
        add_edge!(graph, i, 2)
    end

    # Prints for debug.
    @debug """
        Translation Tables Complete.
        Number of Vertices: $vertex_number.
        Number of Tasks: $(length(node_dict)).
        Number of Components: $(length(component_dict)).
        Number of edges added: $(edges_added).
        """
    return graph, node_dict, component_dict
end

function do_assignment(placement_struct, graph, node_dict, component_dict)
    # Reverse the node and component dictionaries.
    node_dict_rev       = rev_dict(node_dict)
    component_dict_rev  = rev_dict(component_dict)
    # Iterate through all the indices belonging to nodes.
    for i in keys(node_dict_rev)
        # Iterate through all the "in_neighbors" of this node.
        # Looking for an incoming edge that is not from the source.
        # This edge leads to the component this task will be mapped to.
        for neighbor in in_neighbors(graph, i)
            neighbor == 1 && continue
            b = neighbor
            # Get the address and component number from the reversed
            # component dictionary.
            (address, component) = component_dict_rev[b]
            node = node_dict_rev[i]
            assign(placement_struct, node, component, address)
        end
    end
    return nothing
end


"""
bipartite_match!(g::AbstractGraph)
"""
function bipartite_match!(g::AbstractGraph)
    ####################
    # Graph Definition #
    ####################
    # the graph g contains LHS vertices (referred to as "a"),
    #   RHS vertices (referred to as "b"), source vertex, and sink vertex
    # vertex #1 (source) is connected to all members of a (source -> v ∈ a)
    # vertex #2 (sink) is connected to all members of b (v ∈ b -> sink)

    ###################
    # Algorithm rules #
    ###################
    # the algorithm can go from left vertex to right vertex if they are
    #   connected only with "->" edge
    # once that path is being used, another edge "<-" is added
    # the algorithm can go from right vertex to left vertex if they are
    #   connected with both "->" and "<-" edges
    # once that path is being used, the edge "<-" is removed
    # the algorithm ends after exhausting all the "a" vertices
    # "a" set and "b" set will have a one-to-one relation when matching is complete
    # the matched pair will be connected with both "->" and "<-" edges

    # source and sink are defined as 1 and 2 respectively in LightGraph g
    source = 1
    sink = 2
    # group the vertices according to their number of preferences
    sort_dict = SortedDict{Int64,Array{Int64,1}}()
    for a in out_neighbors(g,source)
        count = length(out_neighbors(g,a))
        push_to_dict(sort_dict, count, a)
    end
    # unwrap vertex value array for each key in sort_dict
    a_set = Int64[] # all vertices are stored in a_set
    for v in values(sort_dict)
        append!(a_set, v)
    end
    # source -> a -> b -> sink links are made
    # if link requires a backward trace, it's skipped for now (taken care of later)
    for a in a_set
        for b in out_neighbors(g,a)
            if has_edge(g,b=>sink) && !has_edge(g,sink=>b)
                add_edge!(g,a=>source)
                add_edge!(g,b=>a)
                add_edge!(g,sink=>b)
                break
            elseif has_edge(g,b=>sink) && has_edge(g,sink=>b)
                continue
            end
        end
    end
    # links that require backward tracing are created below
    for a in out_neighbors(g,source)
        has_edge(g,a=>source) && continue
        two_found = false # initialize
        for b in out_neighbors(g,a)
            two_found && break
            predecessor = Int64[] # create an array to keep track the path
            neighbor = b
            previous_neighbor = a
            exit = false # initialize
            while !two_found && !exit
                for new_neighbor in out_neighbors(g,neighbor)
                    # check if neighbor can be connected to sink
                    if (new_neighbor == sink && !has_edge(g,sink=>neighbor))
                        two_found = true
                        push!(predecessor,previous_neighbor)
                        push!(predecessor,neighbor)
                        push!(predecessor,new_neighbor)
                        break
                    end
                    # check if the vertex has no remaining moves
                    if ((out_neighbors(g,neighbor)) == [source,previous_neighbor]
                        ||(in_neighbors(g,neighbor)) == [sink,previous_neighbor])
                        exit = true
                        break
                    end
                    # source, sink, and previous_neighbor are not valid vertices
                    # to move to
                    if (new_neighbor == source  ||
                        new_neighbor == sink    ||
                        new_neighbor == previous_neighbor)
                        continue
                    end
                    if (has_edge(g,neighbor=>sink) &&
                        has_edge(g,neighbor=>new_neighbor) &&
                        has_edge(g,new_neighbor=>neighbor))
                        push!(predecessor,previous_neighbor)
                        previous_neighbor = neighbor
                        neighbor = new_neighbor
                    elseif (has_edge(g,source=>neighbor) &&
                            has_edge(g,neighbor=>new_neighbor) &&
                            !has_edge(g,new_neighbor=>neighbor))
                        push!(predecessor,previous_neighbor)
                        previous_neighbor = neighbor
                        neighbor = new_neighbor
                    else
                        exit = true
                        break
                    end # end of if statement
                end # end of 3rd for loop
            end # end of while loop
            # if sink is found, trace back the predecessors and create appropriate
            # edges as mentioned in the "Algorithm Rules" above
            if two_found
                add_edge!(g,predecessor[1]=>source)
                add_edge!(g,predecessor[2]=>predecessor[1])
                add_edge!(g,sink=>predecessor[end])
                for i = 2:length(predecessor)-1
                    if i in out_neighbors(g,source)
                        add_edge!(g,predecessor[i]=>predecessor[i+1])
                    elseif i in in_neighbors(g,sink)
                        rem_edge!(g,predecessor[i]=>predecessor[i+1])
                    end # end if
                end # end for loop
                break
            end # if two_found
        end # end of 2nd for loop
    end # end of 1st for loop
    return g
end
