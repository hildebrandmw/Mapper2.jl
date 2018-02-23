struct E3Architecture end

function build_general_primitive()
    # Build a simple metadata.
    metadata = Dict("mappable" => true)
    component = Component("primitive", metadata = metadata)
    # Instantiate two output and two input ports.
    # Make the metadata for the two input ports slightly different to test routing
    add_port(component, "in", "input")
    add_port(component, "out", "output")
    
    check(component)
    return component
end

function build_general_tile()
    # Build a simple metadata.
    metadata = Dict("mappable" => false)
    component = Component("tile", metadata = metadata)

    # Add general primitive
    add_child(component, build_general_primitive(), "u0") 

    # Instantiate two output and two input ports.
    # Make the metadata for the two input ports slightly different to test routing
    dirs = ("north", "east", "south", "west", "up", "down")
    for dir in dirs
        add_port(component, "$(dir)_in", "input")
        add_port(component, "$(dir)_out", "output")
    end

    # instantiate a mux 
    add_child(component, build_mux(7,7), "mux") 

    # Start connecting things together
    
    
    check(component)
    return component
end
