@testset "Testing Move Generators" begin
    import Chessboard: SquareColor, Black, White, Gray
    import Base.Iterators.product

    # Use the Chessboard module
    # Build a 4x4 map, completely populate it with tasks.
    board_dims = 4
    m = Chessboard.build_map(board_dims, 16, 32)

    # Build the SA Struct
    sa_struct = SA.SAStruct(m)

    # SA here should have 3 classes for Black, White, and Gray.
    # We need to figure out which class index refers set of processors.
    @test length(sa_struct.maptable.normal) == 3

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
    @show color_to_class_idx

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

    ci_norm(x::CartesianIndex) = sum(abs.(x.I))
    function testlut(sa_struct, move_generator, idx, addrs)
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
                    [a for a in addrs if ci_norm(a - address) <= limit],
                    # Sort addresses by distances from "address"
                    # Then apply the normal CartesianIndex sort.
                    lt = (x, y) -> (ci_norm(x - address) < ci_norm(y - address))  ||
                        (ci_norm(x - address) == ci_norm(y - address) && x < y)
                        
                )
                @test expected_addresses == lut.targets[1:lut.idx]

                # Test that all of the addresses in the targets are within the
                # distance limit and none of the addresses outside this target
                # are within the distance limit.
                norms_below = map(
                    x -> ci_norm(x - address),
                    lut.targets[1:lut.idx]
                )
                @test all(norms_below .<= limit)

                # Test the remainder of the array.
                norms_above = map(
                    x -> ci_norm(x - address), 
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

    #################
    # TESTING WHITE #
    #################
    idx = color_to_class_idx[White]

    addrs = [CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims) if isodd(i+j)]
    testlut(sa_struct, move_generator, idx, addrs)

    #################
    # TESTING BLACK #
    #################
    idx = color_to_class_idx[Black]

    addrs = [CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims) if iseven(i+j)]
    testlut(sa_struct, move_generator, idx, addrs)

    ################
    # TESTING GRAY #
    ################
    idx = color_to_class_idx[Gray]

    addrs = reshape([CI(i,j) for (i,j) in product(1:board_dims, 1:board_dims)], :)
    testlut(sa_struct, move_generator, idx, addrs)

    SA.place(sa_struct, move_attempts = 20)
    @test SA.verify_placement(m, sa_struct)

end
