

@testset "Testing Bipartite Matching" begin

    using LightGraphs

    ############################################################################
    # Auxiliary functions to help with testing.
    ############################################################################
    function build_testgraph(d)
      # create empty array to count the number of elements on RHS
      value_array = []
      for value in values(d)
        for entry in value
          !(in(entry,value_array)) && push!(value_array,entry)
        end
      end
      # number of nodes equals to entries on RHS + entries on LHS + source node
      # + sink node
      g = DiGraph(length(d)+length(value_array)+2)
      # add edges
      for (key, values) in d
        add_edge!(g,1=>key)
        for value in values
          add_edge!(g,(key)=>(value))
          add_edge!(g,(value)=>2)
        end
      end
      return g
    end

    # this function converts the matched graph into a dictionary format used in
    # verification
    function graph2dict(g)
        dict = Dict{Int64,Int64}()
        for a in outneighbors(g,1)
            for b in inneighbors(g,a)
                if (b != 1)
                    dict[a] = b
                end
            end
        end
        return dict
    end


    ############################################################################
    # Perform Test
    ############################################################################

    dict = Dict(3 => [9],
                4 => [9,10,11],
                5 => [11,12],
                6 => [12],
                7 => [12,13],
                8 => [9,13]
                )
    # Convert dict to LightGraph
    graph = build_testgraph(dict)
    # Do matching on the graph
    matched_graph = Mapper2.SA.bipartite_match!(graph)
    # Convert matched graph back to dictonary
    d = graph2dict(matched_graph)
    # Generate expected result
    d_ref = Dict(3 => 9,
                 4 => 10,
                 5 => 11,
                 6 => 12,
                 7 => 13)

    @test length(keys(d_ref)) == length(keys(d))
end
