#=
This file tests the save and load feature of the Mapper.
=#
@testset "Testing Save/Load" begin
    using Example1
    # Create two maps that are the same
    m = place(Example1.make_map(), move_attempts = 5000)
    sm = Mapper2.SAStruct(m)

    # Place struct sm
    Mapper2.SA.place(sm, move_attempts = 5000)
    # Record the placed sm into map m
    Mapper2.SA.record(m, sm)
    m = route(m)
    # Save the placement
    save(m, "tests")

    ##################################
    # Now create a new testmap.
    ##################################
    n = Example1.make_map()
    # Load the placement into "n"
    load(n, "tests")
    # Create a SA struct for the new map.
    sn = Mapper2.SAStruct(n)
    # Preplace "n" into "sn" 
    Mapper2.SA.preplace(n, sn)
    # Assert the two costs are the same.
    @test Mapper2.SA.map_cost(sn) == Mapper2.SA.map_cost(sm)
    # Get the link histograms for the two maps. Make sure they match
    lm = MapperCore.global_link_histogram(m)
    ln = MapperCore.global_link_histogram(n)
    @test lm == ln

    rm("tests.json.gz")
end
