@testset "Testing SA Placememnt Error Checking" begin
    # Create a map, then an SA struct.
    # Make a several illegal moves
    # call "verify placement"

    m = Example1.make_map()
    sa = Mapper2.SA.SAStruct(m)

    ## copy two tasks into the same primitive

    # get the indices for two identical tasks
    x = sa.tasktable["task2"]
    y = sa.tasktable["task2"]

    # # make sure their class matches
    cx = SA.getclass(sa.nodes[x])
    cy = SA.getclass(sa.nodes[y])
    @test cx == cy
    @test cx > 0

    address_array = sa.maptable.normal[cx]
    # Get the first index with a primitive vector greater than zero
    i = findfirst(x -> length(x) > 0, address_array)
    # Convert this into a cartesian index
    addr = CartesianIndices(address_array)[i]
    # Get the primitive.
    c = first(address_array[i])

    # Move both tasks to this primitive
    SA.move(sa, x, SA.Location(addr, c))
    SA.move(sa, y, SA.Location(addr, c))

    @test !SA.verify_placement(m, sa)

    ### Move a node without updating the grid
    # Redo initial placement
    # Initial placement is deterministic so it will be at the same state is
    # was previously
    SA.initial_placement!(sa)

    SA.assign(sa.nodes[y], SA.Location(addr, c))

    @test !SA.verify_placement(m, sa)

    ### Replicate a node in the grid
    SA.initial_placement!(sa)
    sa.grid[1] = x
    sa.grid[2] = x
    @test !SA.verify_placement(m, sa)

    ### Move an input to an illegal location
    SA.initial_placement!(sa)
    z = sa.tasktable["input1"]
    SA.swap(sa, x, z)
    @test !SA.verify_placement(m, sa)

    ### Zero a node in the grid
    SA.initial_placement!(sa)
    addr = SA.getaddress(sa.nodes[x])
    c = SA.getindex(sa.nodes[x])
    sa.grid[c,addr] = 0
    @test !SA.verify_placement(m, sa)
end

@testset "Testing Placements" begin
    # Strategy: Use a bunch of different architectures and a linegraph from
    # Chessboard. Make sure that all get mapped to the minimum.

    # Try the 2D architectures.
    # Use only the "ChessboardColor()" coloring scheme to avoid mismatch between
    # white and black squares that may happen with HashColor
    architectures = (
        architecture(4, Rectangle2D(), ChessboardColor()),
        architecture(4, Hexagonal2D(), ChessboardColor()),
    )

    taskgraphs = (
        linegraph(16, AllGray()),
        linegraph(16, OddEven()),
        linegraph(16, Quarters()),
    )

    move_generators = (
        SA.CachedMoveGenerator,
        SA.SearchMoveGenerator,
    )

    iterator = Iterators.product(
        architectures,
        taskgraphs,
        move_generators,
    )

    for (A, T, movegen) in iterator
        m = Map(Chess(), A,T)

        sa = SA.SAStruct(m)
        move_generator = movegen(sa)
        @time SA.place!(sa, movegen = move_generator)
        # Number of links in the linegraph is 15.
        #
        # All maps should reach this.
        @test Mapper2.SA.map_cost(sa) == 15

        SA.record(m, sa)
        # Route and see that post-routing number of links is correct.
        route!(m)
        @test MapperCore.total_global_links(m) == 15
    end

    # Now test 3D placements
    architectures = (
        architecture(3, Rectangle3D(), ChessboardColor()),
    )

    taskgraphs = (
        linegraph(27, AllGray()),
        linegraph(27, OddEven()),
        linegraph(27, Quarters()),
    )

    move_generators = (
        SA.CachedMoveGenerator,
        SA.SearchMoveGenerator,
    )

    iterator3d = Iterators.product(
        architectures,
        taskgraphs,
        move_generators,
    )

    for (A, T, movegen) in iterator3d
        m = Map(Chess(), A,T)

        sa = SA.SAStruct(m)
        move_generator = movegen(sa)
        @time SA.place!(sa, movegen = move_generator)

        # When checking the number of links, give some leeway for the mapper
        # to not quite reach the minimum.
        #
        # Notable, the Quarters() taskgraph has trouble reaching a final 
        # objective of 26. I think the minimum may in fact be 27.
        @test Mapper2.SA.map_cost(sa) <= 27

        SA.record(m, sa)
        # Route and see that post-routing number of links is correct.
        route!(m)
        @test MapperCore.total_global_links(m) <= 27
    end
end


@testset "Testing Fanout Placement" begin
    m = Example1.make_fanout()
    sa = Mapper2.SA.SAStruct(m)

    Mapper2.SA.place!(sa);
    # The example is small enough that it should achieve this result every time.
    @test Mapper2.SA.map_cost(sa) == 14
end


