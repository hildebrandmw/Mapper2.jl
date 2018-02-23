
function build_primitive()
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
        add_port(component, "$(dir)_in", "input")
        add_port(component, "$(dir)_out", "output")
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

    # Connect all ports together
    key = ""
    val = ""
    fn = x -> true
    src_rule = PortRule(key, val, fn)
    dst_rule = PortRule(key, val, fn)

    offsets = [CartesianIndex(-1, 0, 0),
               CartesianIndex( 1, 0, 0), 
               CartesianIndex( 0, 1, 0), 
               CartesianIndex( 0,-1, 0),
               CartesianIndex( 0, 0, 1), 
               CartesianIndex( 0, 0,-1)]

    src_dirs = ("north", "south", "east", "west", "up",   "down")
    dst_dirs = ("south", "north", "west", "east", "down", "up"  )
    offset_rules = OffsetRule[]
    for (offset, src, dst) in zip(offsets, src_dirs, dst_dirs)
        src_ports = ["$(src)_out"]
        dst_ports = ["$(dst)_in"]
        # Create the offset rule and add it to the collection
        new_rule = OffsetRule([offset], src_ports, dst_ports)
        push!(offset_rules, new_rule)
    end

    connection_rule(a, offset_rules, src_rule, dst_rule)
    check(a)
    return a
end
