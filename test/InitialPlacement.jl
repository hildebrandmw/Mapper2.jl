@testset "Testing Bipartite Matching" begin
    #using Mapper2.SA
    dict = Dict(3 => [9],
                4 => [9,10,11],
                5 => [11,12],
                6 => [12],
                7 => [12,13],
                8 => [9,13]
                )
    graph = Mapper2.SA.build_testgraph(dict)
    matched_graph = Mapper2.SA.bipartite_match!(graph)
    d = Mapper2.SA.graph2dict(matched_graph)
    d_ref = Dict(3 => 9,
                 4 => 10,
                 5 => 11,
                 6 => 12,
                 7 => 13)
    @test length(keys(d_ref)) == length(keys(d))
end
