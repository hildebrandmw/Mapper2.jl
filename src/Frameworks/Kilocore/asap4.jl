function build_asap4(;A = KCBasic)
    # Start with a new component - clarify that it is 2 dimensional
    arch = TopLevel{A,2}("asap4")

    ####################
    # Normal Processor #
    ####################

    # Get a processor tile to instantiate.
    processor = build_processor_tile()
    # Instantiate it at the required addresses
    for r in 1:24, c in 2:28
        add_child(arch, processor, Address{2}(r,c))
    end
    for r in 1:20, c in 29
        add_child(arch, processor, Address{2}(r,c))
    end

    ####################
    # Memory Processor #
    ####################
    memory_processor = build_memory_processor_tile()
    for r = 25, c = 2:28
        add_child(arch, memory_processor, Address{2}(r,c))
    end
    #################
    # 2 Port Memory #
    #################
    memory_2port = build_memory_2port()
    for r = 26, c in (2, 4, 6, 8, 11, 13, 15, 17, 20, 22, 24, 26)
        add_child(arch, memory_2port, Address{2}(r,c))
    end
    #################
    # 1 Port Memory #
    #################
    memory_1port = build_memory_1port()
    for r = 26, c in (10, 19)
        add_child(arch, memory_1port, Address{2}(r,c))
    end
    #################
    # Input Handler #
    #################
    input_handler = build_input_handler()
    for r ∈ (1, 13), c = 1
        add_child(arch, input_handler, Address{2}(r,c))
    end
    for r ∈ (12, 18), c = 30
        add_child(arch, input_handler, Address{2}(r,c))
    end
    ##################
    # Output Handler #
    ##################
    output_handler = build_output_handler()
    for (r,c) ∈ zip((12,18,1,14), (1, 1, 30, 30))
        add_child(arch, output_handler, Address{2}(r,c))
    end

    #######################
    # Global Interconnect #
    #######################
    connect_processors(arch)
    connect_memories(arch)
    return arch
end

function connect_processors(tl)
    # General rule - we're looking for the attribute "processor" to be somewhere
    # in the component stack. If so, we'll try to connect all of the circuit
    # switched ports.
    src_key = "attributes"
    src_val = ["processor", "input_handler", "output_handler"]
    src_fn = oneofin
    src_rule = PortRule(src_key, src_val, src_fn)
    dst_rule = src_rule
    # Create offset rules.
    # Offsets are just unit steps in four directions.
    offsets = [Address{2}(-1,0), Address{2}(1,0), Address{2}(0,1), Address{2}(0,-1)]
    #=
    Create two tuples for the source ports and destination ports. In general,
    if the source link is going out of the north port, the destionation will
    be coming in the sourth port.
    =#
    src_dirs = ("north", "south", "east", "west")
    dst_dirs = ("south", "north", "west", "east")
    offset_rules = OffsetRule[]
    for (offset, src, dst) in zip(offsets, src_dirs, dst_dirs)
        src_ports = String[]
        dst_ports = String[]
        # Iterate through the number of source and destination ports.
        for i in 0:1
            src_port = src * "_out[" * string(i) * "]"
            push!(src_ports, src_port)
            dst_port = dst * "_in[" * string(i) * "]"
            push!(dst_ports, dst_port)
        end
        # Create the offset rule and add it to the collection
        new_rule = OffsetRule([offset], src_ports, dst_ports)
        push!(offset_rules, new_rule)
    end
    # Create offset rules for the input and output handlers.
    # Input and output handlers only appear on the left and right hand sides
    # of the array, so only need the "east" and "west" directions.
    src_dirs = ("east","west")
    dst_dirs = ("west","east")
    # Links can go both directions, so make the offsets an array
    offsets = [Address{2}(0,1), Address{2}(0,-1)]
    for (offset, src, dst) in zip(offsets, src_dirs, dst_dirs)
        src_ports = String[]
        dst_ports = String[]
        for i in 0:1
            # Input handler -> processor
            src_port = "out[" * string(i) * "]"
            dst_port = dst * "_in[" * string(i) * "]"
            push!(src_ports, src_port)
            push!(dst_ports, dst_port)
            # processor -> output handler
            src_port = src * "_out[" * string(i) * "]"
            dst_port = "in[" * string(i) * "]"
            push!(src_ports, src_port)
            push!(dst_ports, dst_port)
        end
        new_rule = OffsetRule([offset], src_ports, dst_ports)
        push!(offset_rules, new_rule)
    end
    # Build metadata dictionary for capacity and cost
    metadata = Dict(
        "cost"      => 1.0,
        "capacity"  => 1,
        "network"   => ["circuit_switched"]
    )
    # Launch the function call!
    connection_rule(tl, offset_rules, src_rule, dst_rule, metadata = metadata)
    return nothing
end


function connect_memories(tl)
    # Create metadata dictionary for the memory links.
    metadata = Dict(
        "cost"      => 1.0,
        "capacity"  => 1,
        "network"   => ["memory"],
   )
    ########################### 
    # Connect 2 port memories #
    ########################### 
    # Create rule for the memory processors
    proc_key = "attributes"
    proc_val = "memory_processor"
    proc_fn = in
    proc_rule = PortRule(proc_key, proc_val, proc_fn)
    # Create rule for the 2-port memories.
    mem_key = "attributes"
    mem_val = "memory_2port"
    mem_fn  = in
    mem_rule = PortRule(mem_key, mem_val, mem_fn)
    # Make connections from memory to memory-processors
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{2}(-1,0), "out[0]", "memory_in"))
    push!(offset_rules, OffsetRule(Address{2}(-1,1), "out[1]", "memory_in"))
    connection_rule(tl, offset_rules, mem_rule, proc_rule, metadata = metadata)
    # Make connections from memory-processors to memories.
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{2}(1,0), "memory_out", "in[0]"))
    push!(offset_rules, OffsetRule(Address{2}(1,-1), "memory_out", "in[1]"))
    connection_rule(tl, offset_rules, proc_rule, mem_rule, metadata = metadata)

    ########################### 
    # Connect 1 port memories #
    ########################### 
    # Change the memory attribute requirement to a 1 port memory.
    mem_val = "memory_1port"
    mem_rule = PortRule(mem_key, mem_val, mem_fn)
    # Make connections from memory to memory-processors
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{2}(-1,0), "out[0]", "memory_in"))
    connection_rule(tl, offset_rules, mem_rule, proc_rule, metadata = metadata)
    # Make connections from memory-processors to memories.
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{2}(1,0), "memory_out", "in[0]"))
    connection_rule(tl, offset_rules, proc_rule, mem_rule, metadata = metadata)

    return nothing
end

##################
# COMPLEX BLOCKS #
##################
function build_processor_tile(name = "processor_tile", include_memory = false)
    # Working towards parameterizing this. For now, just leave this at two
    # because the "processor" components aren't parameterized for the number
    # of ports. This should be easy to fix though.
    num_links = 2
    # Create a new component for the processor tile
    # No need to set the primtiive class or metadata because we won't
    # be needing it.
    comp = Component(name)
    # Add the circuit switched ports
    directions = ("east", "north", "south", "west")
    for dir in directions
        for (suffix,class)  in zip(("_in", "_out"), ("input", "output"))
            port_name = join((dir, suffix))
            add_port(comp, port_name, class, num_links)
        end
    end
    # Instantiate the processor primitive
    add_child(comp, build_processor(include_memory), "processor")
    # Instantiate the directional routing muxes
    routing_mux = build_mux(4,1)
    for dir in directions
        name = join((dir, "_mux"))
        add_child(comp, routing_mux, name, num_links)
    end
    # Instantiate the muxes routing data to the fifos
    add_child(comp, build_mux(9,1), "fifo_mux", 2)
    # Add memory ports - only memory processor tiles will have the necessary
    # "memory_processor" attribute in the core to allow memory application
    # to be mapped to them.
    if include_memory
        add_port(comp, "memory_in", "input")
        add_port(comp, "memory_out", "output")
        connect_ports!(comp, "processor.memory_out", "memory_out")
        connect_ports!(comp, "memory_in", "processor.memory_in")
    end

    # Interconnect - Don't attach metadata and let the routing routine fill in
    # defaults to intra-tile routing.

    # Connect outputs of muxes to the tile outputs
    for dir in directions, i = 0:num_links-1
        mux_port = join((dir, "_mux[",string(i),"].out"))
        tile_port = join((dir, "_out[",string(i),"]"))
        connect_ports!(comp, mux_port, tile_port)
    end
    # Circuit switch output links
    connect_ports!(comp, "processor.north[0]", ["north_mux[0].in[0]"])
    connect_ports!(comp, "processor.north[1]", ["north_mux[1].in[0]"])
    connect_ports!(comp, "processor.east[0]",  ["east_mux[0].in[0]"])
    connect_ports!(comp, "processor.east[1]",  ["east_mux[1].in[0]"])
    connect_ports!(comp, "processor.south[0]", ["south_mux[0].in[0]"])
    connect_ports!(comp, "processor.south[1]", ["south_mux[1].in[0]"])
    connect_ports!(comp, "processor.west[0]",  ["west_mux[0].in[0]"])
    connect_ports!(comp, "processor.west[1]",  ["west_mux[1].in[0]"])

    # Input Links
    connect_ports!(comp, "fifo_mux[0].out", ["processor.fifo[0]"])
    connect_ports!(comp, "fifo_mux[1].out", ["processor.fifo[1]"])
    # Connect input ports to inputs of muxes
    #=
    TODO: Throw this in a loop to make it easier to do.

    Also - think about how to parameterize this to allow for more generic
    routing and construction.
    =#
    connect_ports!(comp, "north_in[0]", [ "east_mux[0].in[1]",
                                        "south_mux[0].in[1]",
                                        "west_mux[0].in[1]",
                                        "fifo_mux[0].in[0]",
                                        "fifo_mux[1].in[0]"])
    connect_ports!(comp, "north_in[1]", [ "east_mux[1].in[1]",
                                        "south_mux[1].in[1]",
                                        "west_mux[1].in[1]",
                                        "fifo_mux[0].in[1]",
                                        "fifo_mux[1].in[1]"])
    connect_ports!(comp, "east_in[0]", [ "north_mux[0].in[1]",
                                        "south_mux[0].in[2]",
                                        "west_mux[0].in[2]",
                                        "fifo_mux[0].in[2]",
                                        "fifo_mux[1].in[2]"])
    connect_ports!(comp, "east_in[1]", [ "north_mux[1].in[1]",
                                        "south_mux[1].in[2]",
                                        "west_mux[1].in[2]",
                                        "fifo_mux[0].in[3]",
                                        "fifo_mux[1].in[3]"])
    connect_ports!(comp, "south_in[0]", [ "north_mux[0].in[2]",
                                        "east_mux[0].in[2]",
                                        "west_mux[0].in[3]",
                                        "fifo_mux[0].in[4]",
                                        "fifo_mux[1].in[4]"])
    connect_ports!(comp, "south_in[1]", [ "north_mux[1].in[2]",
                                        "east_mux[1].in[2]",
                                        "west_mux[1].in[3]",
                                        "fifo_mux[0].in[5]",
                                        "fifo_mux[1].in[5]"])
    connect_ports!(comp, "west_in[0]", [ "north_mux[0].in[3]",
                                        "east_mux[0].in[3]",
                                        "south_mux[0].in[3]",
                                        "fifo_mux[0].in[6]",
                                        "fifo_mux[1].in[6]"])
    connect_ports!(comp, "west_in[1]", [ "north_mux[1].in[3]",
                                        "east_mux[1].in[3]",
                                        "south_mux[1].in[3]",
                                        "fifo_mux[0].in[7]",
                                        "fifo_mux[1].in[7]"])
    return comp
end

function build_memory_processor_tile()
    # Get a normal processor and add the memory ports to it.
    tile = build_processor_tile("memory_processor", true)
    # Need to add the memory processor attribute the processor.
    push!(tile.children["processor"].metadata["attributes"], "memory_processor")
    return tile
end

# PRIMITIVE BLOCKS
##############################
#           MUXES
##############################
"""
    build_mux(inputs, outputs)

Build a mux with the specified number of inputs and outputs.
"""
function build_mux(inputs, outputs)
    name = "mux_" * string(inputs) * "_" * string(outputs)
    component = Component(name, primitive = "mux")
    add_port(component, "in", "input", inputs)
    add_port(component, "out", "output", outputs)
    return component
end
##############################
#        PROCESSOR
##############################
"""
    build_processor()

Build a simple processor.
"""
function build_processor(include_memory = false)
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["processor"]
    if include_memory
        name = "memory_processor"
    else
        name = "standard_processor"
    end
    component = Component(name, primitive = "", metadata = metadata)
    # Add the input fifos
    add_port(component, "fifo", "input", 2)
    # Add the output ports
    for str in ("north", "east", "south", "west")
        add_port(component, str, "output", 2)
    end
    # Add the dynamic circuit switched network
    add_port(component, "dynamic", "output", 1)
    # Add memory ports. Will only be connected in the memory processor tile.
    if include_memory
        add_port(component, "memory_in", "input")
        add_port(component, "memory_out", "output")
    end
    # Return the created type
    return component
end

##############################
#      1 PORT MEMORY
##############################
function build_memory_1port()
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["memory_1port"]
    component = Component("memory_1port", primitive = "", metadata = metadata)
    # Add the input and output ports
    add_port(component, "in[0]", "input", 1)
    add_port(component, "out[0]", "output", 1)
    # Return the created type
    return component
end

##############################
#      2 PORT MEMORY         #
##############################
function build_memory_2port()
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["memory_1port", "memory_2port"]
    component = Component("memory_2port", primitive = "", metadata = metadata)
    # Add the input and output ports
    add_port(component, "in", "input", 2)
    add_port(component, "out", "output", 2)
    # Return the created type
    return component
end

##############################
#       INPUT HANDLER        #
##############################
function build_input_handler()
    # Build the metadata dictionary for the input handler
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["input_handler"]
    component = Component("input_handler", primitive = "", metadata = metadata)
    # Add the input and output ports
    add_port(component, "out", "output", 2)
    # Return the created type
    return component
end

##############################
#       OUTPUT HANDLER       #
##############################
function build_output_handler()
    # Build the metadata dictionary for the input handler
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["output_handler"]
    component = Component("output_handler", primitive = "", metadata = metadata)
    # Add the input and output ports
    add_port(component, "in", "input", 2)
    # Return the created type
    return component
end
