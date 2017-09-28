#=
Test suite for the Architecture and Constructor files
=#
@testset "Testing Ports" begin
    #=
    Some simple tests for the port class
    =#
    # Create a port and try some of the specialized methods for it
    port = Port("test", "input")
    # This port does not have a "." in its name, so it should classify as a
    # top level port
    @test Mapper2.is_top_port(port) == true
    # Make a few versions with a "." in the name
    port = Port("test.1", "input")
    @test Mapper2.is_top_port(port) == false
    # This should really throw an error, but accept it for now
    port = Port(".test1", "input")
    @test Mapper2.is_top_port(port) == false
    port = Port("test1.", "input")
    @test Mapper2.is_top_port(port) == false
    # Test the "flipdir" function
    port = Port("test", "input")
    @test Mapper2.flipdir(port) == "output"
    port = Port("test", "output")
    @test Mapper2.flipdir(port) == "input"
    port = Port("test", "bidir")
    @test Mapper2.flipdir(port) == "bidir"
    # Test throwing of errors if trying to instantiate a port with a class
    # that is not valid
    @test_throws AssertionError Port("test", "THIS_IS_NOT_A_CLASS")
end

#=
Test set for the Components/constructors for components.
=#
@testset "Testing Components" begin
    # Make a new component
    metadata = Dict("levels" => 10, "metric" => "stantard")
    component = Component("test", primitive = "test", metadata = metadata)
    # Add three ports to the component, an input, output, and bidirectional
    ports = Dict{String, Port}()
    ports["input"] = Port("input", "input")
    ports["output"] = Port("output", "output")
    ports["bidir"]  = Port("bidir", "bidir")
    # Add all the ports to the component
    Mapper2.add_port(component, values(ports)...)
    # Test some parameters of the merging
    @test length(component.ports) == 3
    for (k,v) in ports
        @test component.ports[v.name] == v
    end
    @test component.metadata == metadata
    # Now create a higher-level component to test nesting 
    higher = Component("upper")
    inst_name = "my_instantiation"
    Mapper2.add_child(higher, component, inst_name)
    # Make sure some parameters about the ports automatically added to the higher
    # component still work
    @test length(higher.ports) == 3
    println("Higher Level Ports:")
    for (k,v) in higher.ports
        println(k)
    end
    # Make sure the port names line up with what is expected
    expected_names = map(x -> join((inst_name,x),"."), collect(keys(ports)))
    @test sort(collect(keys(higher.ports))) == sort(expected_names)
end


