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
    DEBUG && print_with_color(:cyan, "Bipartite Matching Complete\n")
    do_assignment(placement_struct, graph, node_dict, component_dict)
    return graph
end

function build_graph(sa::SAStruct)
    #=
    Build translation tables.
    - Tasks will be mapped to verticies with an index number 2 higher than their
    index in the SAstruct. (Verticies 1 and 2 are reserved for source and sink)
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
    keytype = Tuple{Address{dimension(sa)},Int64}
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
        address = Address(subscripts)
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
            address = Address(ind2sub(maptable, index))
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
    if DEBUG
        print_with_color(:cyan, "Building Translation Tables\n")
        print_with_color(:green, "Number of vertices: ")
        println(vertex_number)
        print_with_color(:green, "Number of tasks: ")
        println(length(node_dict))
        print_with_color(:green, "Number of components: ")
        println(length(component_dict))
        print_with_color(:green, "Number of edges added: ")
        println(edges_added)
    end
    return graph, node_dict, component_dict
end


"""
    do_assignment(placement_struct, graph, node_dict, component_dict)


"""
function do_assignment(placement_struct, graph, node_dict, component_dict)
    # Reverse the node and component dictionaries.
    node_dict_rev       = rev_dict(node_dict)
    component_dict_rev  = rev_dict(component_dict)
    # Iterate through all the indices belonging to nodes.
    for i in keys(node_dict_rev)
        # Iterate through all the "in_neighbors" of this node.
        # Looking for an incoming edge that is not from the source.
        # This edge leads to the component this task will be mapped to.
        if length(in_neighbors(graph, i)) != 2
            error()
        end
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

Implementation of Ford-Fulkerson algorithm for maximum bipartite matching
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

    numberofLHS = length(out_neighbors(g,1))
    numberofRHS = length(in_neighbors(g,2))
    if numberofLHS > numberofRHS
        error("The number of vertices on LHS is greater",
              " than the number of vertices on RHS.")
    end

    # loop through all the tasks (LHS of graph)
    source = 1
    sink   = 2
    for a in out_neighbors(g,source)
        # mark as being used
        add_edge!(g,a=>1)
        b_count = 1
        for b in out_neighbors(g,a)
            # the path goes from a to b (therefore, ignore the source)
            b == source && continue
            b_count += 1
            # check if the b -> 2 edge is still available for usage
            if !has_edge(g,sink=>b)
                # mark as being used
                add_edge!(g,b=>a)
                # if the flow to the sink (vertex #2) is available,
                # mark as being used and break
                add_edge!(g,sink=>b)
                break
            else
                # try again with another b (that is out neighbor of a)
                if b_count < length(out_neighbors(g,a))
                    continue
                # if vertex is the last neighbor of a, the algorithm rules
                # (mentioned above) need to be applied here to complete the
                # algorithm
                elseif b_count == length(out_neighbors(g,a))
                    # mark as being used
                    add_edge!(g,b=>a)
                    # set initial conditions for while loop
                    neighbor = b
                    previous_neighbor = a
                    # initial condition
                    exit = false
                    two_found = true
                    while (!(sink in out_neighbors(g,neighbor) &&
                                !has_edge(g,2=>neighbor) &&
                                has_edge(g,neighbor=>sink)) && !exit)
                        neighbor_count = 0
                        length_neighbors = length(out_neighbors(g,neighbor))
                        # check if there is a valid place to move next
                        if ((out_neighbors(g,neighbor)) == [source,previous_neighbor]
                            || (out_neighbors(g,neighbor)) ==
                            [sink,previous_neighbor])
                            two_found = false
                            error("Error: Bipartite Matching Incomplete")
                            break
                        end
                        for new_neighbor in out_neighbors(g,neighbor)
                            neighbor_count += 1
                            # prevents the path from going backwards or going
                            # to source or to sink with a used edge
                            if (new_neighbor == source  ||
                                new_neighbor == sink    ||
                                new_neighbor == previous_neighbor)
                                continue
                            end
                            # if the current vertex is on the "a" side, trying
                            # to go to "b" next
                            if has_edge(g,source=>neighbor)
                                if (has_edge(g,neighbor=>new_neighbor) &&
                                    !has_edge(g,new_neighbor=>neighbor))
                                    add_edge!(g,new_neighbor=>neighbor)
                                    previous_neighbor = neighbor
                                    neighbor = new_neighbor
                                else
                                    if neighbor_count < length_neighbors
                                        # find a usable edge
                                        continue
                                    elseif neighbor_count == length_neigbors
                                        # if no more usable edges left, then exit loop
                                        exit = true
                                    end
                                end
                            # if the current vertex is on the "b" side, trying
                            # to go to "a" next
                            elseif has_edge(g,neighbor=>sink)
                                if (has_edge(g,neighbor=>new_neighbor) &&
                                    has_edge(g,new_neighbor=>neighbor))
                                    rem_edge!(g,neighbor,new_neighbor)
                                    previous_neighbor = neighbor
                                    neighbor = new_neighbor
                                else
                                    if neighbor_count < length_neighbors
                                        # find a usuable edge
                                        continue
                                    elseif neighbor_count == length_neighbors
                                        # if no more usable edges left, then exit loop
                                        exit = true
                                    end
                                end
                            end
                        end#forloop
                    end#while
                    two_found && add_edge!(g,sink=>neighbor)
                end #ifandelseif
            end #if
        end #secondfor
    end #firstfor
    return g
end

