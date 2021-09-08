@testset "Testing Path Types" begin
    using Mapper2.MapperCore
    # Path Constructors
    let
        # Empty constructors
        ref = Path{Nothing}(String[])
        @test ref == Path{Nothing}()
        @test ref == Path{Nothing}("")

        # Various constructors.
        ref = Path{Nothing}(["a", "b", "c"])
        @test ref == Path{Nothing}("a.b.c")
        @test ref == Path{Nothing}("a", "b", "c")
        # Test fallback inequality
        @test Path{Nothing}("a.b.c") != Path{Int}("a.b.c")

        @test first(Path{Nothing}("a.b.c")) == "a"
        @test first(Path{Nothing}("a")) == "a"
        @test last(Path{Nothing}("a.b.c")) == "c"
        @test last(Path{Nothing}("c")) == "c"
    end
    # Length tests
    let
        @test length(Path{Nothing}("a.b.c")) == 3
        @test length(Path{Nothing}("a.b")) == 2
        @test length(Path{Nothing}("a")) == 1
        @test length(Path{Nothing}()) == 0
    end
    # Test dictionaries
    let
        paths = [Path{Nothing}("a.b.c"), Path{Int}("a.b.c"), Path{Nothing}("r")]

        d = Dict(paths[i] => i for i in 1:length(paths))

        for i in 1:length(paths)
            @test d[paths[i]] == i
        end
    end
end

@testset "Testing Ports" begin
    name = "test"
    meta = Dict("bob" => 10)
    p = Port(name, Input; metadata = meta)
    @test checkclass(p, MapperCore.Source) == true
    @test checkclass(p, MapperCore.Sink) == false

    pi = MapperCore.invert(p)
    @test pi.name == name
    @test pi.class == Output
    @test pi.metadata == meta

    # Error with incorrect class
    @test_throws Exception Port(name, :not_a_class)

    # Invert an output
    @test MapperCore.invert(MapperCore.invert(p)) == p
end

@testset "Testing Architecture Modeling" begin
    # Use Example1 for this testing.
    # Test General primitive
    let
        p = build_general_primitive()
        @test sort(collect(keys(p.ports))) == ["in[0]", "in[1]", "out[0]", "out[1]"]
        @test assert_no_children(p)
        @test assert_no_intrarouting(p)
    end
    let
        t = build_io_tile()
        @test assert_no_children(t) == false
        @test assert_no_intrarouting(t) == false
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "input")
        @test search_metadata!(t, "task", "output")
    end

    expected_ports = sort([
        "north_out",
        "north_in",
        "south_out",
        "south_in",
        "east_out",
        "east_in",
        "west_out",
        "west_in",
    ])

    let
        t = build_general_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
        @test assert_no_children(t) == false
        @test assert_no_intrarouting(t) == false
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "general")
    end
    let
        t = build_super_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
        @test assert_no_children(t) == false
        @test assert_no_intrarouting(t) == false
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "general")
    end
    let
        t = build_double_general_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
        @test assert_no_children(t) == false
        @test assert_no_intrarouting(t) == false
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "general")
    end
    let
        t = build_routing_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
        @test assert_no_children(t) == false
        @test assert_no_intrarouting(t) == false
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "general") == false
    end
    let
        t = build_test_arch()
        # Do a recusrive search to find the correct task
        @test search_metadata!(t, "task", "general") == true
    end
end
