#=
Test architectures for testing the Mapper as a whole.

Strategy: Build a small 3x3 heterogenous array using a variety of nesting,
and different primitives to test everything was written properly.
=#

################################################################################
# Primitive used in the test architecture
################################################################################
function build_general_primitive()
    # Build a simple metadata.
    metadata = Dict("task" => "general")
    component = Component("general_primitive", metadata = metadata)
    # Instantiate two output and two input ports.
    # Make the metadata for the two input ports slightly different to test routing
    add_port(component, "in", "input", 2, metadata = Dict("capacity" => 1))
    add_port(component, "out[0]", "output",
             metadata = Dict("class" => "A", "capacity" => 1))
    add_port(component, "out[1]", "output",
             metadata = Dict("class" => "B", "capacity" => 1))
    
    check(component)
    return component
end

function build_input_primitive()
    metadata = Dict("task" => "input")
    component = Component("input_primitive", metadata = metadata)
    add_port(component, "out", "output", metadata = Dict("capacity" => 1))
    check(component)
    return component
end

function build_output_primitive()
    metadata = Dict("task" => "output")
    component = Component("output_primitive", metadata = metadata)
    add_port(component, "in", "input", metadata = Dict("capacity" => 1))
    check(component)
    return component
end

################################################################################
# Tiles used in the test architecture
################################################################################
function build_io_tile()
    # Create a skeleton tile
    tile = Component("io_tile")
    # Create IO ports for the four directions
    dir_tuple = ("north", "east", "south", "west")
    for dir in dir_tuple
        add_port(tile, "$(dir)_in", "input")
        add_port(tile, "$(dir)_out", "output")
    end
    # Instantiate an input primitive and output primitive
    add_child(tile, build_input_primitive(), "input")
    add_child(tile, build_output_primitive(), "output")
    # Instantiate a mux for routing. Needs 5 inputs and 5 outptus
    add_child(tile, build_mux(5,5), "routing_mux")
    # Create Links
    connect_ports(tile, "input.out", "routing_mux.in[0]")
    connect_ports(tile, "routing_mux.out[0]", "output.in")
    metadata = Dict{String,Any}("capacity" => 5)
    for (count, dir) in enumerate(dir_tuple)
        connect_ports(tile, "routing_mux.out[$count]","$(dir)_out", metadata)
        connect_ports(tile, "$(dir)_in", "routing_mux.in[$count]", metadata)
    end
    check(tile)
    return tile
end

function build_general_tile()
    # Create a skeleton
    tile = Component("general_tile")
    # Create IO ports for the four directions
    dir_tuple = ("north", "east", "south", "west")
    for dir in dir_tuple
        add_port(tile, "$(dir)_in", "input")
        add_port(tile, "$(dir)_out", "output")
    end
    # Instantiate a General Component
    add_child(tile, build_general_primitive(), "general")
    # Instantiate a mux for routing. Needs 5 inputs and 5 outptus
    add_child(tile, build_mux(6,6), "routing_mux")
    # Create Links
    connect_ports(tile, "general.out[0]", "routing_mux.in[0]")
    connect_ports(tile, "general.out[1]", "routing_mux.in[5]")
    connect_ports(tile, "routing_mux.out[0]", "general.in[0]")
    connect_ports(tile, "routing_mux.out[5]", "general.in[1]")
    metadata = Dict{String,Any}("capacity" => 5)
    for (count, dir) in enumerate(dir_tuple)
        connect_ports(tile, "routing_mux.out[$count]","$(dir)_out", metadata)
        connect_ports(tile, "$(dir)_in", "routing_mux.in[$count]", metadata)
    end
    check(tile)
    return tile
end

function build_super_tile()
    # Create a skeleton
    tile = Component("super_tile")
    # Create IO ports for the four directions
    dir_tuple = ("north", "east", "south", "west")
    for dir in dir_tuple
        add_port(tile, "$(dir)_in", "input")
        add_port(tile, "$(dir)_out", "output")
    end
    # Instantiate a General Component
    add_child(tile, build_general_primitive(), "general", 2)
    # Instantiate a mux for routing. Needs 5 inputs and 5 outptus
    add_child(tile, build_mux(8,8), "routing_mux")
    # Create Links
    connect_ports(tile, "general[0].out[0]", "routing_mux.in[0]")
    connect_ports(tile, "general[0].out[1]", "routing_mux.in[5]")
    connect_ports(tile, "general[1].out[0]", "routing_mux.in[6]")
    connect_ports(tile, "general[1].out[1]", "routing_mux.in[7]")
    connect_ports(tile, "routing_mux.out[0]", "general[0].in[0]")
    connect_ports(tile, "routing_mux.out[5]", "general[0].in[1]")
    connect_ports(tile, "routing_mux.out[6]", "general[1].in[0]")
    connect_ports(tile, "routing_mux.out[7]", "general[1].in[1]")
    metadata = Dict{String,Any}("capacity" => 6)
    for (count, dir) in enumerate(dir_tuple)
        connect_ports(tile, "routing_mux.out[$count]","$(dir)_out", metadata)
        connect_ports(tile, "$(dir)_in", "routing_mux.in[$count]", metadata)
    end
    check(tile)
    return tile
end

function build_double_general_tile()
    tile = Component("double_general")
    dir_tuple = ("north", "east", "south", "west")
    # Instantiate a general tile inside of this one
    add_child(tile, build_general_tile(), "general")
    metadata = Dict{String,Any}("capacity" => 5)
    for dir in dir_tuple
        add_port(tile, "$(dir)_in", "input")
        add_port(tile, "$(dir)_out", "output")
        connect_ports(tile, "general.$(dir)_out", "$(dir)_out", metadata)
        connect_ports(tile, "$(dir)_in", "general.$(dir)_in", metadata)
    end
    check(tile)
    return tile 
end

# Tile testing single source driving multiple sinks
function build_routing_tile()
    tile = Component("routing_tile")
    add_child(tile, build_mux(8,4), "routing_mux")
    # Instantiate a bunch of 1 to 1 muxes
    dir_tuple = ("north", "east", "south", "west")
    # Instantiate a general tile inside of this one
    metadata = Dict{String,Any}("capacity" => 5)

    a_metadata = Dict("capacity" => 5, "class" => "A", "cost" => 1.0)
    b_metadata = Dict("capacity" => 5, "class" => "B", "cost" => 10.0)
    for (i,dir) in enumerate(dir_tuple)
        add_port(tile, "$(dir)_in", "input")
        add_port(tile, "$(dir)_out", "output")
        add_child(tile, build_mux(1,1), "mux_$(dir)", 2)

        connect_ports(tile,
                      "$(dir)_in",
                      ["mux_$(dir)[0].in[0]", "mux_$(dir)[1].in[0]"],
                      metadata)

        connect_ports(tile,"mux_$dir[0].out[0]", "routing_mux.in[$(2*(i-1))]", 
                      a_metadata)
        connect_ports(tile,"mux_$dir[1].out[0]", "routing_mux.in[$(2*(i-1)+1)]", 
                      b_metadata)

        connect_ports(tile,"routing_mux.out[$(i-1)]", "$(dir)_out", metadata)
    end
    check(tile)
    return tile
end

"""
Test architecture. Consists of a 3x3 array of tiles consisting of a variety of
structures intended to test various features of the Mapper.
"""
function build_test_arch()
    arch = TopLevel{TestArchitecture,2}("test_arch")
    # Add IO Tiles
    io_tile = build_io_tile()
    for address in (Address(1,1), Address(3,3))
        add_child(arch, io_tile, address)
    end
    # Add general tiles
    gen_tile = build_general_tile()
    for address in (Address(1,2), Address(3,2))
        add_child(arch, gen_tile, address)
    end
    # Add super tiles
    sup_tile = build_super_tile()
    for address in (Address(2,1), Address(2,3))
        add_child(arch, sup_tile, address)
    end
    # Add double general tiles
    double_tile = build_double_general_tile()
    for address in (Address(1,3), Address(3,1))
        add_child(arch, double_tile, address)
    end
    # Add the routing tile
    routing_tile = build_routing_tile()
    add_child(arch, routing_tile, Address(2,2))

    # Connect all ports together
    key = ""
    val = ""
    fn = x -> true
    src_rule = PortRule(key, val, fn)
    dst_rule = PortRule(key, val, fn)

    offsets = (Address(-1,0), Address(1,0), Address(0,1), Address(0,-1))
    src_dirs = ("north", "south", "east", "west")
    dst_dirs = ("south", "north", "west", "east")
    offset_rules = OffsetRule[]
    for (offset, src, dst) in zip(offsets, src_dirs, dst_dirs)
        src_ports = ["$(src)_out"]
        dst_ports = ["$(dst)_in"]
        # Create the offset rule and add it to the collection
        new_rule = OffsetRule([offset], src_ports, dst_ports)
        push!(offset_rules, new_rule)
    end
    # Build metadata dictionary for capacity and cost
    metadata = Dict{String,Any}("capacity"  => 5)
    # Launch the function call!
    connection_rule(arch, offset_rules, src_rule, dst_rule, metadata = metadata)
    check(arch)
    return arch
end



################################################################################
# Testing the functions and final architecture
################################################################################

