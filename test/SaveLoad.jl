#=
This file tests the save and load feature of the Mapper.
=#
@testset "Testing Save/Load" begin
    # Create two maps that are the same
    m = Mapper2.testmap()
    sm = Mapper2.SAStruct(m)
    # Place struct sm
    Mapper2.place(sm, move_attempts = 5000)
    # Record the placed sm into map m
    Mapper2.record(m, sm)
    # Save the placement
    Mapper2.save(m, "tests")
    
    ##################################
    # Now create a new testmap.
    ##################################
    n = Mapper2.testmap()
    # Load the placement into "n"
    Mapper2.load(n, "tests")

    # Create a SA struct for the new map.
    sn = Mapper2.SAStruct(n)
    # Preplace "n" into "sn" 
    Mapper2.preplace(n, sn)
    # Assert the two costs are the same.
    @test Mapper2.map_cost(sn) == Mapper2.map_cost(sm)

end