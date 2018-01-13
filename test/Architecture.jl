@testset "Testing Path Types" begin
    using Mapper2.Architecture
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

        a = AddressPath(Address(1,1,1), c)
        @test PortPath("a.b.c.name", Address(1,1,1)) == PortPath(name, a)
    end
    # Test Link Paths
end

