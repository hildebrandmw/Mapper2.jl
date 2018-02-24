@testset "Testing Path Types" begin
    using Mapper2.MapperCore
    # Test Component Path Constructors
    let
        # Test some empty constructor notations
        empty = ComponentPath(String[])
        @test ComponentPath() == empty
        @test ComponentPath("") == empty
        
        # Test the automatic splitting along dots
        C = ComponentPath("a.b.c")
        @test C == ComponentPath(["a","b","c"])
        @test length(ComponentPath("a.b.c")) == 3
        @test prefix(C) == ["a","b"]

        # Some address path tests
        A = AddressPath(CartesianIndex(1), ComponentPath(""))
        @test length(A) == 1
        @test typestring(C) == "Component"
        @test typestring(A) == "Component"
    end
    # Testing Port Paths
    let
        # Build a Port Path from scratch
        c = ComponentPath("a.b.c")
        name = "name"

        @test PortPath("a.b.c.name") == PortPath(name, c)
        @test isglobalport(c) == false
        @test isgloballink(c) == false

        a = AddressPath(CartesianIndex(1,1,1), c)
        @test PortPath("a.b.c.name", CartesianIndex(1,1,1)) == PortPath(name, a)
        @test isglobalport(a) == false
        @test isgloballink(a) == false

        b = PortPath("a", CartesianIndex(1,1))
        @test isglobalport(b) == true
        @test isgloballink(b) == false
    end
    # Test Link Paths
    
end

@testset "Testing Architecture Modeling" begin
    using Example1

    # Some poor error handling checks
    @test_throws Exception Port("test", :not_a_class)

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
