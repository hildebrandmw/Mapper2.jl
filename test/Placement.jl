@testset "Testing SA Placememnt Error Checking" begin
    # Create a map, then an SA struct.
    # Make a several illegal moves
    # call "verify placement"

    m = Example1.make_map()

    sa = Mapper2.SA.SAStruct(m)

    ## copy two tasks into the same primitive

    # get the indices for two identical tasks
    x = sa.task_table["task2"]
    y = sa.task_table["task2"]

    # make sure their class matches
    cx = sa.nodeclass[x]
    cy = sa.nodeclass[y]
    @test cx == cy
    @test cx > 0

    address_array = sa.maptables[cx]
    # Get the first index with a primitive vector greater than zero
    i = findfirst(x -> length(x) > 0, address_array)
    # Convert this into a cartesian index
    addr = CartesianIndex(ind2sub(address_array, i))
    # Get the primitive.
    c = first(address_array[i])

    # Move both tasks to this primitive
    SA.move(sa, x, c, addr)
    SA.move(sa, y, c, addr)

    @test !SA.verify_placement(m, sa)

    ### Move a node without updating the grid
    # Redo initial placement
    # Initial placement is deterministic so it will be at the same state is
    # was previously
    SA.initial_placement!(sa)

    sa.nodes[y].address = addr
    sa.nodes[y].component = c

    @test !SA.verify_placement(m, sa)

    ### Replicate a node in the grid
    SA.initial_placement!(sa)
    sa.grid[1] = x
    sa.grid[2] = x
    @test !SA.verify_placement(m, sa)

    ### Move an input to an illegal location
    SA.initial_placement!(sa)
    z = sa.task_table["input1"]
    SA.swap(sa, x, z)
    @test !SA.verify_placement(m, sa)

    ### Zero a node in the grid
    SA.initial_placement!(sa)
    addr = sa.nodes[x].address
    c = sa.nodes[x].component
    sa.grid[c,addr] = 0
    @test !SA.verify_placement(m, sa)
end

@testset "Testing Fanout Placement" begin
    m = Example1.make_fanout()
    sa = Mapper2.SA.SAStruct(m)

    Mapper2.SA.place(sa);
    @test Mapper2.SA.map_cost(sa) == 14
end
