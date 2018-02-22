@testset "Testing Path Types" begin
    using Mapper2.MapperCore
    # Test Component Path Constructors
    let
        # Test some empty constructor notations
        empty = ComponentPath(String[])
        @test ComponentPath() == empty
        @test ComponentPath("") == empty
        
        # Test the automatic splitting along dots
        @test ComponentPath("a.b.c") == ComponentPath(["a","b","c"])
    end
    # Testing Port Paths
    let
        # Build a Port Path from scratch
        c = ComponentPath("a.b.c")
        name = "name"

        @test PortPath("a.b.c.name") == PortPath(name, c)

        a = AddressPath(CartesianIndex(1,1,1), c)
        @test PortPath("a.b.c.name", CartesianIndex(1,1,1)) == PortPath(name, a)
    end
    # Test Link Paths
end

@testset "Testing Architecture Modeling" begin
    using Example
    # Test General primitive
    let
        p = build_general_primitive()
        @test sort(collect(keys(p.ports))) == ["in[0]","in[1]","out[0]","out[1]"]
    end
    let
        t = build_io_tile()
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
    end
    let
        t = build_super_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
    end
    let
        t = build_double_general_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
    end
    let
        t = build_routing_tile()
        sorted_ports = sort(collect(keys(t.ports)))
        @test sorted_ports == expected_ports
    end
    let
        t = build_test_arch()
    end
end
