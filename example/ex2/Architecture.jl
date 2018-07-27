
function build_primitive()
    # Build a simple metadata.
    metadata = Dict("mappable" => true)
    component = Component("primitive", metadata = metadata)
    # Instantiate two output and two input ports.
    # Make the metadata for the two input ports slightly different to test routing
    add_port(component, "in", Input)
    add_port(component, "out", Output)
    
    check(component)
    return component
end

function build_tile()
    # Build a simple metadata.
    metadata = Dict("mappable" => false)
    component = Component("tile", metadata = metadata)

    # Add general primitive
    add_child(component, build_primitive(), "u0") 

    # Instantiate two output and two input ports.
    # Make the metadata for the two input ports slightly different to test routing
    dirs = ("north", "east", "south", "west", "up", "down")
    for dir in dirs
        add_port(component, "$(dir)_in", Input)
        add_port(component, "$(dir)_out", Output)
    end

    # instantiate a mux 
    add_child(component, build_mux(7,7), "mux") 

    ## Links

    # Component to mux
    add_link(component, "u0.out", "mux.in[0]")    
    add_link(component, "mux.out[0]", "u0.in")

    # Mux to tile i/o
    for (i,d) in enumerate(dirs)
        add_link(component, "mux.out[$i]", "$(d)_out")
        add_link(component, "$(d)_in", "mux.in[$i]")
    end
    
    check(component)
    return component
end

function build_arch()
    a = TopLevel{Test3d,3}("arch_3d")
    tile = build_tile()

    # Instantiate tiles
    for (i,j,k) in Iterators.product(1:3, 1:3, 1:3)
        add_child(a, tile, CartesianIndex(i,j,k))
    end

    offsets = [
        Offset((-1, 0, 0), "north_out", "south_in"),
        Offset(( 1, 0, 0), "south_out", "north_in"),
        Offset(( 0, 1, 0), "east_out", "west_in"),
        Offset(( 0,-1, 0), "west_out", "east_in"),
        Offset(( 0, 0, 1), "up_out", "down_in"),
        Offset(( 0, 0,-1), "down_out", "up_in"),
    ]

    connection_rule(a, offsets)
    check(a)
    return a
end
