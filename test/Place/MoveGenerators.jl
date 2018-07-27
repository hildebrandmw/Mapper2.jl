function testlut(
        # The SA structure that is being placed.
        sa_struct, 
        # Instantied move_generator. It is assumed that this generator has
        # already been initialized.
        move_generator :: SA.CachedMoveGenerator, 
        # Class index currently under test.
        idx :: Integer, 
        # List of addresses of tiles that it is expected that this class
        # maps to.
        addrs,
        # Distance function between addresses. Useful for using this same
        # function for Cartesian architectures and hexagonal architectures.
        dist :: Function,
   )
    # Get the move dictionary form the Move Generagor for this index .
    move_dict = move_generator.moves[idx]

    # Make sure that the keys of this dictionary match the expected 
    # addresses.
    @test sort(collect(keys(move_dict))) == sort(addrs)

    # Test all limits for this geometry.
    for limit in SA.distancelimit(move_generator, sa_struct):-1:1
        # Update the move generator.
    SA.update!(move_generator, sa_struct, limit)

        # Iterate over all valid addresses. We'll recompute what the 
        # collection of moves should look like from scratch and verify
        # the match.
        for (address, lut) in move_dict
            # Compute the expected set of addresses from scratch.
            expected_addresses = sort(
                [a for a in addrs if dist(a, address) <= limit],
                # Sort addresses by distances from "address"
                # Then apply the normal CartesianIndex sort.
                lt = (x, y) -> (dist(x, address) < dist(y, address))  ||
                    (dist(x, address) == dist(y, address) && x < y)
                    
            )
            @test expected_addresses == lut.targets[1:lut.idx]

            # Test that all of the addresses in the targets are within the
            # distance limit and none of the addresses outside this target
            # are within the distance limit.
            norms_below = map(
                x -> dist(x, address),
                lut.targets[1:lut.idx]
            )
            @test all(norms_below .<= limit)

            # Test the remainder of the array.
            norms_above = map(
                x -> dist(x, address), 
                lut.targets[lut.idx+1:end]
            )
            @test all(norms_above .> limit)

            # Test random move genertion.
            # Only test (and thus fail) if generation fails.
            for _ in 1:1000
                rand_address = rand(lut)
                if rand_address ∉ expected_addresses
                    @test in(rand_address, expected_addresses)
                end
            end
        end
    end
end

function get_colors(m :: Map, sa_struct :: SA.SAStruct)
    # Decode the classes.
    color_to_class_idx = Dict{SquareColor, Int}()

    tasktable_rev = Dict(v => k for (k,v) in sa_struct.tasktable)
    for (idx, node) in enumerate(sa_struct.nodes)
        class = SA.getclass(node)
        taskname = tasktable_rev[idx]
        color = getnode(m.taskgraph, taskname).metadata["color"]

        # Initialize and check the colors.
        if !haskey(color_to_class_idx, color)
            color_to_class_idx[color] = class
        else
            @test color_to_class_idx[color] == class
        end
    end

    return color_to_class_idx
end

################################################################################
@testset "Testing Move Generators" begin
    import Base.Iterators.product


    # Use the Chessboard module
    # Build a 4x4 rectangular architecture with chessboard coloring.
    board_dims = 4
    A = architecture(
        board_dims, 
        Rectangle2D(),
        ChessboardColor(),
    )
    # Construct a taskgraph that will entierly fill the architecture.
    # Color it so 1/4 the tasks are Black, 1/4 are White, and 1/2 are Gray.
    T = taskgraph(
        board_dims ^ 2,
        board_dims ^ 2 + board_dims,
        Quarters()
    )

    m = Map(A,T)

    # Build the SA Struct
    sa_struct = SA.SAStruct(m)

    # SA here should have 3 classes for Black, White, and Gray.
    # We need to figure out which class index refers set of processors.
    @test length(sa_struct.maptable.normal) == 3

    color_to_class_idx = get_colors(m, sa_struct)

    # Should have found all of the colors.
    @test length(color_to_class_idx) == 3

    # Chess Board:
    #
    # B W B W
    # W B W B
    # B W B W 
    # W B W B

    # Initialize a CachedMoveGenerator. 
    move_generator = SA.CachedMoveGenerator{SA.location_type(sa_struct.maptable)}()

    # Test that the maximum distance from corner to corner is correct.
    @test SA.distancelimit(move_generator, sa_struct) == 2 * (board_dims - 1)
    # Initialize the move generator.
    SA.initialize!(move_generator, sa_struct)

    # Convenience Definition
    CI = CartesianIndex

    euclidean(x, y) = sum(abs.((x - y).I))

    #################
    # TESTING WHITE #
    #################
    idx = color_to_class_idx[White]

    addrs = [CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims) if isodd(i+j)]
    testlut(sa_struct, move_generator, idx, addrs, euclidean)

    #################
    # TESTING BLACK #
    #################
    idx = color_to_class_idx[Black]

    addrs = [CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims) if iseven(i+j)]
    testlut(sa_struct, move_generator, idx, addrs, euclidean)

    ################
    # TESTING GRAY #
    ################
    idx = color_to_class_idx[Gray]

    addrs = reshape([CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims)], :)
    testlut(sa_struct, move_generator, idx, addrs, euclidean)

    SA.place!(sa_struct, move_attempts = 20)
    @test SA.verify_placement(m, sa_struct)

end

@testset "Big Move Generator Test" begin
    # In this test, we're going to try the 3D, 2D, hexagonal architectures with
    # the Chessboard and Hash color schemes. In all cases, the 
    # CachedMoveGenerator should generate correct results ... hopefully.

    # Distance between two coordinates using rectilinear coordinates.
    euclidean(x, y) = sum(abs.((x - y).I))
    function hexagonal(a, b)
        # Break cartesian indices into their components.
        x0, y0 = a[1], a[2]
        x1, y1 = b[1], b[2]

        # Find the distance between y coordinages
        d = abs(y1-y0)

        # Compute how many diagonal steps we can take given the y displacement.
        #
        # Because of the awkward offset in the hexagonal architecture, we have
        # to check if we're on an even column or not.
        if isodd(y0)
            x_hi = x0 + (d >> 1)
            x_lo = x0 - ((d+1) >> 1)
        else
            x_hi = x0 + ((d+1) >> 1)
            x_lo = x0 - (d >> 1)
        end

        # Check the location of the "x" coordinate relative to the number of
        # diagonal steps we could have taken. If the "x" coordinate is outside
        # of the bound, we have to take some more hops to get there. Otherwise,
        # it "x" is inside that bound, we don't have to take any extra steps.
        if x1 < x_lo
            dist = d + x_lo - x1
        elseif x1 > x_hi
            dist = d + x1 - x_hi
        else
            dist = d
        end

        return dist
    end


    # Build the maps.
    maps = [
        (Map(
            architecture(4, Rectangle2D(), ChessboardColor()),
            taskgraph(16, 20, Quarters())
        ), euclidean),

        (Map(
            architecture(4, Rectangle2D(), HashColor()),
            taskgraph(16, 20, Quarters())
        ), euclidean),

        (Map(
            architecture(3, Rectangle3D(), ChessboardColor()),
            taskgraph(27, 40, Quarters())
        ), euclidean),

        (Map(
            architecture(3, Rectangle3D(), HashColor()),
            taskgraph(27, 40, Quarters())
        ), euclidean),

        (Map(
            architecture(4, Hexagonal2D(), ChessboardColor()),
            taskgraph(16, 24, Quarters())
        ), hexagonal),
    ]

    for (m, dist) in maps
        sa_struct = SA.SAStruct(m)

        # Get the color to class index mapping
        color_to_class_idx = get_colors(m, sa_struct)
        # Should have found all of the colors.
        @test length(color_to_class_idx) == 3

        # Initialize a CachedMoveGenerator. 
        move_generator = SA.CachedMoveGenerator{SA.location_type(sa_struct.maptable)}()
        # Initialize the move generator.
        SA.initialize!(move_generator, sa_struct)

        # Iterate through all colors
        for color in (White, Black, Gray)
            # Get the class index for this color
            idx = color_to_class_idx[color]
            # Search through all the addresses in the architecture. Get the ones 
            # where the mappable component has the color in question.
            if color == Gray
                addrs = collect(addresses(m.architecture))
            else
                addrs = [
                    a for a in addresses(m.architecture) 
                    if search_metadata!(m.architecture[a], "color", color, ==)
                ]
            end

            # Test the move generator
            testlut(sa_struct, move_generator, idx, addrs, dist)
        end
    end
end
