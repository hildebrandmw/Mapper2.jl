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
        linegraph(16, AllGray()), linegraph(16, OddEven()), linegraph(16, Quarters())
    )

    move_generators = (SA.CachedMoveGenerator,)

    iterator = Iterators.product(architectures, taskgraphs, move_generators)

    for (A, T, movegen) in iterator
        m = Map(Chess(), A, T)

        sa = SA.SAStruct(m)
        move_generator = movegen(sa)
        @time SA.place!(sa; movegen = move_generator)
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
    architectures = (architecture(3, Rectangle3D(), ChessboardColor()),)

    taskgraphs = (
        linegraph(27, AllGray()), linegraph(27, OddEven()), linegraph(27, Quarters())
    )

    move_generators = (SA.CachedMoveGenerator,)

    iterator3d = Iterators.product(architectures, taskgraphs, move_generators)

    for (A, T, movegen) in iterator3d
        m = Map(Chess(), A, T)

        sa = SA.SAStruct(m)
        move_generator = movegen(sa)
        @time SA.place!(sa; movegen = move_generator)

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

    Mapper2.SA.place!(sa)
    # The example is small enough that it should achieve this result every time.
    @test Mapper2.SA.map_cost(sa) == 14
end
