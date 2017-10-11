#=
Authors:
    Arthur Hlaing
    Mark Hildebrand

Provides a Bipartite matching routine to do initial placement of a taskgraph
to an placement structure.
=#

"""
initialplacement(app_name::String, pa::Dict{Address,Array{String,1}})

Performs initial placement of tasks onto the architecture using bipartite matching
"""
function initialplacement(app_name::String, pa::Dict{Address,Array{String,1}})
    filepath = joinpath(PKGDIR, "taskgraphs", app_name * ".json")
    f = open(filepath,"r")
    json = JSON.parse(f)
    close(f)

    # Addresses from the ProcArray and TaskNames are converted to Int64
    # are referenced back using the Dicts below

    # task names to Int64 storage Dict and vice-versa
    task_string2int = Dict{String,Int64}()
    task_int2string = Dict{Int64,String}()
    # addr names to Int64 storage Dict and vice-versa
    addr_addr2int = Dict{Address,Int64}()
    addr_int2addr = Dict{Int64,Address}()
    # converted Int64 IDs and their corresponding attributes
    task_attributes = Dict{Int,Array{String,1}}()
    addr_attributes = Dict{Int,Array{String,1}}()

    # Taskname String to Int64 conversion
    task_count = 0
    for value in values(json["summary"])
        for i = 1:length(value)
            task_count += 1
            task_string2int[value[i]] = task_count
            task_int2string[task_count]= value[i]
        end
    end

    # Address type to Int64 conversion
    addr_count = 0
    for key in keys(pa)
        addr_count += 1
        addr_addr2int[key] = addr_count
        addr_int2addr[addr_count] = key
    end

    # This will allow attribute requirement look-up using Int64
    for task in json["tasks"]
        task_name = task["name"]
        if !haskey(task,"metadata")
            println(task_name)
        end
        metadata = task["metadata"]
        attributes = metadata["attribute_requirements"]
        task_attributes[task_string2int[task_name]] = attributes
    end

    # This will allow attribute look-up using Int64
    for (key,value) in pa
        addr_attributes[addr_addr2int[key]] = value
    end

    # graph is created for bipartite matching
    g = graph(task_attributes, addr_attributes)
    # graph is passed into the algorithm
    bp_graph = bipartite_match(g)
    # matched graph is translated back into type recognizable by other mapper modules
    placement_dict = translate(bp_graph, task_int2string, addr_int2addr)

    return placement_dict
end
"""
bipartite_match(g::AbstractGraph)

Implementation of Ford-Fulkerson algorithm for maximum bipartite matching
"""
function bipartite_match(g::AbstractGraph)

    ####################
    # Graph Definition #
    ####################
    # the graph g contains LHS vertices (referred to as "a"), RHS vertices (referred to as "b"), source vertex, and sink vertex
    # vertex #1 (source) is connected to all members of a (source -> v ∈ a)
    # vertex #2 (sink) is connected to all members of b (v ∈ b -> sink)

    ###################
    # Algorithm rules #
    ###################
    # the algorithm can go from left vertex to right vertex if they are connected only with "->" edge
    # once that path is being used, another edge "<-" is added
    # the algorithm can go from right vertex to left vertex if they are connected with both "->" and "<-" edges
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
    for a in out_neighbors(g,1) 
        # mark as being used
        add_edge!(g,a=>1) 
        b_count = 1
        for b in out_neighbors(g,a)
            # the path goes from a to b (therefore, ignore the source)
            b == 1 && continue 
            b_count += 1
            # check if the b -> 2 edge is still available for usage
            if !has_edge(g,2=>b) 
                # mark as being used
                add_edge!(g,b=>a)
                # if the flow to the sink (vertex #2) is available, 
                # mark as being used and break
                add_edge!(g,2=>b) 
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
                    while !(2 in out_neighbors(g,neighbor) && !has_edge(g,2=>neighbor) && has_edge(g,neighbor=>2)) && !exit
                        for new_neighbor in out_neighbors(g,neighbor)
                            # prevents the path from going backwards or going 
                            # to source or to sink with a used edge
                            if new_neighbor == 1 || new_neighbor == 2 || new_neighbor == previous_neighbor 
                                continue
                            end
                            # if the current vertex is on the "a" side, trying 
                            # to go to "b" next
                            if has_edge(g,1=>neighbor) && has_edge(g,neighbor=>new_neighbor) && !has_edge(g,new_neighbor=>neighbor) 
                                add_edge!(g,new_neighbor=>neighbor)
                                previous_neighbor = neighbor
                                neighbor = new_neighbor
                            # if the current vertex is on the "b" side, trying 
                            # to go to "a" next
                            elseif has_edge(g,neighbor=>2) && has_edge(g,neighbor=>new_neighbor) && has_edge(g,new_neighbor=>neighbor) 
                                rem_edge!(g,neighbor,new_neighbor)
                                previous_neighbor = neighbor
                                neighbor = new_neighbor
                            else
                                # if no more usable edges left, then exit loop
                                exit = true 
                            end#ifstatement
                        end#forloop
                    end#while
                    add_edge!(g,2=>neighbor)
                end #ifandelseif
            end #if
        end #secondfor
    end #firstfor
    return g
end
"""
graph(a_attributes::Dict{Int,Array{String,1}}, b_attributes::Dict{Int,Array{String,1}})

Creates an AbstractGraph from two dictionaries (LHS and RHS) for maxiumum bipartite matching
"""
function graph(a_attributes::Dict{Int,Array{String,1}}, b_attributes::Dict{Int,Array{String,1}})

    # + 2 comes from the source and sink vertices addition for bipartite matching
    nv = length(a_attributes) + length(b_attributes) + 2
    adj_matrix = zeros(nv,nv)
    offset = length(a_attributes)

    # form an edge going from a_attributes to b_attributes if there is a preference
    # between a member of a_attributes and a member of b_attributes
    # the edges and their directions are indicated in a form of adjacency matrix
    for i = 1:length(a_attributes)
        for j = 1:length(b_attributes)
            if issubsetof(a_attributes[i],b_attributes[j])
                adj_matrix[i+2,j+2+offset] = 1
            end
        end
    end

    # connect source (vertex 1) and vertices in a_attributes
    adj_matrix[1,3:length(a_attributes)+2] = 1
    # connect sink (vertex 2) and vertices in b_attributes
    adj_matrix[offset+3:end,2] = 1

    return DiGraph(adj_matrix) # returns a directed graph that will be used later for bipartite matching

end

"""
translate(g::AbstractGraph, task_int2string::Dict{Int64,String}, addr_int2addr::Dict{Int64,Address})

Translates the matched AbstractGraph back into the type recognizable by kc architectures
"""
function translate(g::AbstractGraph, task_int2string::Dict{Int64,String}, addr_int2addr::Dict{Int64,Address})
    # numberofLHS : number of tasks
    numberofLHS = length(out_neighbors(g,1))
    # this dict will be used to store the data recognizable by kc archs
    placement_dict = Dict{String,Address}()

    # a starts at 3; 1 and 2 are used as source and sink respectively for bipartite matching
    # using the reference dicts, the Int64 IDs are converted back into their actual names
    for a = 3:numberofLHS+2
        for neighbor in in_neighbors(g,a)
            neighbor == 1 && continue # do not want vertex #1 (source) in the output
            # after bipartite matching, the graph should be one-to-one function going from a to b
            b = neighbor
            placement_dict[task_int2string[a-2]] = addr_int2addr[b-numberofLHS-2]
        end
    end
    return placement_dict
end

