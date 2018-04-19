@testset "Testing Path Types" begin
    using Mapper2.MapperCore
    # Path Constructors
    let
        # Empty constructors
        ref = Path{Void}(String[])
        @test ref == Path{Void}()
        @test ref == Path{Void}("")

        # Various constructors.
        ref = Path{Void}(["a", "b", "c"])
        @test ref == Path{Void}("a.b.c")
        @test ref == Path{Void}("a", "b", "c")
        # Test fallback inequality
        @test Path{Void}("a.b.c") != Path{Int}("a.b.c")

        @test first(Path{Void}("a.b.c")) == "a"
        @test first(Path{Void}("a")) == "a"
        @test last(Path{Void}("a.b.c")) == "c"
        @test last(Path{Void}("c")) == "c"
    end
    # Length tests
    let
        @test length(Path{Void}("a.b.c")) == 3
        @test length(Path{Void}("a.b")) == 2
        @test length(Path{Void}("a")) == 1
        @test length(Path{Void}()) == 0
    end
    # Test dictionaries
    let
        paths = [
            Path{Void}("a.b.c"),
            Path{Int}("a.b.c"),
            Path{Void}("r"),
        ]

        d = Dict(paths[i] => i for i in 1:length(paths))

        for i in 1:length(paths)
            @test d[paths[i]] == i
        end
    end
end

@testset "Testing Ports" begin
    name = "test"
    meta = Dict("bob" => 10)
    p = Port(name, :input, meta)
    @test checkclass(p, :source) == true
    @test checkclass(p, :sink) == false

    pi = MapperCore.invert(p)
    @test pi.name == name
    @test pi.class == :output
    @test pi.metadata == meta

    # Error with incorrect class
    @test_throws Exception Port(name, :not_a_class)

    # Invert an output
    @test MapperCore.invert(MapperCore.invert(p)) == p
end


@testset "Testing Architecture Modeling" begin
    using Example1

    # Test General primitive
    let
        p = build_general_primitive()
        @test sort(collect(keys(p.ports))) == ["in[0]","in[1]","out[0]","out[1]"]
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
    expected_ports = sort(["north_out",
                           "north_in",
                           "south_out",
                           "south_in",
                           "east_out",
                           "east_in",
                           "west_out",
                           "west_in"])

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

