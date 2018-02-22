#=
This file tests the save and load feature of the Mapper.
=#
@testset "Testing Save/Load" begin
    using Example
    # Create two maps that are the same
    m = place(make_map(), move_attempts = 5000)
    sm = Mapper2.SAStruct(m)

    # Place struct sm
    Mapper2.SA.place(sm, move_attempts = 5000)
    # Record the placed sm into map m
    Mapper2.SA.record(m, sm)
    # Save the placement
    save(m, "tests")

    ##################################
    # Now create a new testmap.
    ##################################
    n = make_map()
    # Load the placement into "n"
    load(n, "tests")
    # Create a SA struct for the new map.
    sn = Mapper2.SAStruct(n)
    # Preplace "n" into "sn" 
    Mapper2.SA.preplace(n, sn)
    # Assert the two costs are the same.
    @test Mapper2.SA.map_cost(sn) == Mapper2.SA.map_cost(sm)

    rm("tests.json.gz")

end
