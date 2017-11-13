function build_generic(row::Int64, col::Int64, lev::Int64, dict::Dict{String,Any}
                        ;A = KCBasic, num_links = 2)

    # check for memory_dict key in the bigger dictionary
    if haskey(dict, "input_handler")
        num_in = dict["input_handler"]
    end

    if haskey(dict, "memory_dict")
        mem_dict = dict["memory_dict"]
    else
        # if dict does not contain memory_dict, initialize an empty array
        mem_dict = Dict{Mapper2.Address{3},Vector{Mapper2.Address{3}}}()
    end

    # Check the dimension
    if lev == 1
        dim = 2
    elseif lev > 1
        dim = 3
    else
        error("The level argument is invalid.")
    end

    # direction definitions
    directions2d = ("north", "east", "south", "west")
    directions3d = ("north", "east", "south", "west", "top", "bottom")
    directions = (directions2d,directions3d)

    # Start with a new component
    arch = TopLevel{A,3}("generic")

    # make empty arrays for memory addresses and memory neighbor addresses
    mem_array = Address[]
    mem_proc_array = Address[]
    # move the addresses from mem_dict to arrays
    for (key,value) in mem_dict
        push!(mem_array,key)
        for addr in value
            push!(mem_proc_array,addr)
        end
    end

	####################
    # Normal Processor #
    ####################
    # Get a processor tile to instantiate
	processor = build_processor_tile_generic(dim,directions)
    # Instantiate it at the required addresses
  	for r in 1:row, c in 2:col+1, l in 1:lev
        if Address(r,c,l) in mem_proc_array || Address(r,c,l) in mem_array
            continue # avoid the addresses in mem_dict
        end
		add_child(arch, processor, Address(r,c,l))
  	end

	####################
   	# Memory Processor #
   	####################
   	memory_processor = build_memory_processor_tile_generic(dim,directions)
   	for addr in mem_proc_array
	  	add_child(arch, memory_processor, addr)
   	end

    #################
    # 2 Port Memory #
    #################
    memory_2port = build_memory_2port()
    for addr in mem_array
        add_child(arch, memory_2port, addr)
    end

    #################
    # Input Handler #
    #################
    input_handler = build_input_handler(num_links)
    s = floor(row/num_in) # spacing
    for i = 0:num_in-1
        row = Int(1+(s*i))
        println(row)
        add_child(arch, input_handler, Address(row,1,1))
    end
    ##################
    # Output Handler #
    ##################
    output_handler = build_output_handler(num_links)
    add_child(arch, output_handler, Address(1,col+2,1))

    #######################
    # Global Interconnect #
    #######################
    connect_processors_generic(arch,dim)
    connect_memories_generic(arch)
    return arch

end

##############################
#        PROCESSOR
##############################
"""
    build_processor()

Build a simple processor.
"""
function build_processor_generic(dimension::Int64,
directions::Tuple{NTuple{4,String},NTuple{6,String}})

    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["processor"]
    component = Component(  "standard_processor",
                            primitive = "", metadata = metadata)
    # Add the input fifos
    add_port(component, "fifo", "input", 2)
    # Add the output ports
    for dir in directions[dimension-1]
        add_port(component, dir, "output", 2)
    end
    # Add the dynamic circuit switched network
    add_port(component, "dynamic", "output", 1)
    # Add memory ports. Will only be connected in the memory processor tile.
    add_port(component, "memory_in", "input")
    add_port(component, "memory_out", "output")
    # Return the created type
    return component

end

##################
# COMPLEX BLOCKS #
##################
function build_processor_tile_generic(dimension::Int64,
directions::Tuple{NTuple{4,String},NTuple{6,String}})
    # Working towards parameterizing this. For now, just leave this at two
    # because the "processor" components aren't parameterized for the number
    # of ports. This should be easy to fix though.
    num_links = 2
    # Create a new component for the processor tile
    # No need to set the primtiive class or metadata because we won't
    # be needing it.
    comp = Component("processor_tile")
    # Add the circuit switched ports
    for dir in directions[dimension-1]
        for (suffix,class)  in zip(("_in", "_out"), ("input", "output"))
            port_name = join((dir, suffix))
            add_port(comp, port_name, class, num_links)
        end
    end
    # Add memory ports - only memory processor tiles will have the necessary
    # "memory_processor" attribute in the core to allow memory applicationa
    # to be mapped to them.
    add_port(comp, "memory_in", "input")
    add_port(comp, "memory_out", "output")
    # Instantiate the processor primitive
    add_child(comp, build_processor_generic(dimension,directions), "processor")
    # Instantiate the directional routing muxes
    routing_mux = build_mux(length(directions[dimension-1]),1)
    for dir in directions[dimension-1]
        name = join((dir, "_mux"))
        add_child(comp, routing_mux, name, num_links)
    end
    # Instantiate the muxes routing data to the fifos
    add_child(comp, build_mux(  (length(directions[dimension-1])*2)+1,1),
                                "fifo_mux", 2)

    # Interconnect - Don't attach metadata and let the routing routine fill in
    # defaults to intra-tile routing.
    connect_ports!(comp, "processor.memory_out", "memory_out")
    connect_ports!(comp, "memory_in", "processor.memory_in")

    # Connect outputs of muxes to the tile outputs
    for dir in directions[dimension-1], i = 0:num_links-1
        mux_port = join((dir, "_mux[",string(i),"].out"))
        tile_port = join((dir, "_out[",string(i),"]"))
        connect_ports!(comp, mux_port, tile_port)
    end
    # Circuit switch output links
    for dir in directions[dimension-1], i = 0:num_links-1
        processor_port = join(("processor.",dir,"[",string(i),"]"))
        mux_port = join((dir, "_mux[",string(i),"].in[0]"))
        connect_ports!(comp,processor_port,mux_port)
    end

    # Input Links
    connect_ports!(comp, "fifo_mux[0].out", ["processor.fifo[0]"])
    connect_ports!(comp, "fifo_mux[1].out", ["processor.fifo[1]"])
    # Connect input ports to inputs of muxes
    dir_count = 0
    fifo_count = 0
    dir_tracker = Dict(d => 0 for d in directions[dimension-1])
    for dir in directions[dimension-1]
        dir_count += 1
        for i = 0:num_links-1
            fifo_count += 1
            tile_port = join((dir, "_in[",string(i),"]"))
            sink_ports = String[]
            for d in directions[dimension-1]
                if d == dir
                    dir_tracker[d] = 1
                    continue
                end
                mux_port = join((d, "_mux[",string(i),"].in[",
                                string(dir_count-dir_tracker[d]),"]"))
                push!(sink_ports,mux_port)
            end
            push!(sink_ports,join(("fifo_mux[0].in[",string(fifo_count-1),"]")))
            push!(sink_ports,join(("fifo_mux[1].in[",string(fifo_count-1),"]")))
            connect_ports!(comp, tile_port, sink_ports)
        end
    end
    return comp

end

function build_memory_processor_tile_generic(dimension::Int64,
directions::Tuple{NTuple{4,String},NTuple{6,String}})
    # Get a normal processor and add the memory ports to it.
    tile = build_processor_tile_generic(dimension,directions)
    # Need to add the memory processor attribute the processor.
    push!(tile.children["processor"].metadata["attributes"], "memory_processor")
    return tile
end

function connect_processors_generic(tl,dimension)
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
    offsets2d = [Address{3}(-1,0,0), Address{3}(1,0,0), Address{3}(0,1,0),
                Address{3}(0,-1,0)]
    offsets3d = [Address{3}(-1,0,0), Address{3}(1,0,0), Address{3}(0,1,0),
                Address{3}(0,-1,0), Address{3}(0,0,1), Address(0,0,-1)]
    offsets = (offsets2d,offsets3d)
    #=
    Create two tuples for the source ports and destination ports. In general,
    if the source link is going out of the north port, the destionation will
    be coming in the south port.
    =#
    src_dirs2d = ("north", "south", "east", "west")
    dst_dirs2d = ("south", "north", "west", "east")
    src_dirs3d = ("north", "south", "east", "west", "top", "bottom")
    dst_dirs3d = ("south", "north", "west", "east", "bottom", "top")
    src_dirs = (src_dirs2d,src_dirs3d)
    dst_dirs = (dst_dirs2d,dst_dirs3d)

    offset_rules = OffsetRule[]
    for (offset, src, dst) in zip(offsets[dimension-1], src_dirs[dimension-1],
    dst_dirs[dimension-1])
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
    offsets = [Address{3}(0,1,0), Address{3}(0,-1,0)]
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

function connect_memories_generic(tl)
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
    push!(offset_rules, OffsetRule(Address{3}(-1,0,0), "out[0]", "memory_in"))
    push!(offset_rules, OffsetRule(Address{3}(-1,1,0), "out[1]", "memory_in"))
    connection_rule(tl, offset_rules, mem_rule, proc_rule, metadata = metadata)
    # Make connections from memory-processors to memories.
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{3}(1,0,0), "memory_out", "in[0]"))
    push!(offset_rules, OffsetRule(Address{3}(1,-1,0), "memory_out", "in[1]"))
    connection_rule(tl, offset_rules, proc_rule, mem_rule, metadata = metadata)

    ###########################
    # Connect 1 port memories #
    ###########################
    # Change the memory attribute requirement to a 1 port memory.
    mem_val = "memory_1port"
    mem_rule = PortRule(mem_key, mem_val, mem_fn)
    # Make connections from memory to memory-processors
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{3}(-1,0,0), "out[0]", "memory_in"))
    connection_rule(tl, offset_rules, mem_rule, proc_rule, metadata = metadata)
    # Make connections from memory-processors to memories.
    offset_rules = OffsetRule[]
    push!(offset_rules, OffsetRule(Address{3}(1,0,0), "memory_out", "in[0]"))
    connection_rule(tl, offset_rules, proc_rule, mem_rule, metadata = metadata)

    return nothing
end
