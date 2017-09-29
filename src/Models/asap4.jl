#=
Model for asap4
=#

const _attributes = [
      "processor",
      "memory_processor",
      "fast_processor",
      "viterbi",
      "fft",
      "input_handler",
      "output_handler",
      "memory_1port",
      "memory_2port",
   ]

function build_asap4()
    # Start with a new component - clarify that it is 2 dimensional
    arch = TopLevel{2}("asap4") 
    
    ####################
    # Normal Processor #
    ####################

    # Get a processor tile to instantiate.
    processor = build_processor_tile()
    # Instantiate it at the required addresses
    for r in 1:24, c in 2:26
        add_child(arch, processor, Address(r,c))
    end
    for r in 1:20, c in 27
        add_child(arch, processor, Address(r,c))
    end

    ####################
    # Memory Processor #
    ####################
    memory_processor = build_memory_processor_tile()
    for r = 25, c = 2:28
       add_child(arch, memory_processor, Address(r,c))
    end
    #################
    # 2 Port Memory #
    #################
    memory_2port = build_memory_2port()
    for r = 26, c in (2, 4, 6, 8, 11, 13, 15, 17, 20, 22, 24, 26)
       add_child(arch, memory_2port, Address(r,c))
    end
    #################
    # 1 Port Memory #
    #################
    memory_1port = build_memory_1port()
    for r = 26, c in (10, 19)
       add_child(arch, memory_1port, Address(r,c))
    end
    #################
    # Input Handler #
    #################
    input_handler = build_input_handler() 
    for r ∈ (1, 13), c = 1
       add_child(arch, input_handler, Address(r,c))
    end
    for r ∈ (12, 18), c = 29
       add_child(arch, input_handler, Address(r,c))
    end
    ##################
    # Output Handler #
    ##################
    output_handler = build_output_handler()
    for (r,c) ∈ zip((12,18,1,14), (1, 1, 29, 29))
       add_child(arch, output_handler, Address(r,c))
    end

    #######################
    # Global Interconnect #
    #######################
    #connect_processors!(tl)
    return arch
end

function connect_processors(tl)
    # General rule - we're looking for the attribute "processor" to be somewhere
    # in the component stack. If so, we'll try to connect all of the circuit
    # switched ports.
    src_key = "attributes"
    src_val = ["processor", "input_handler", "output_handler"]
    src_function = in
    dst_key = src_key
    dst_val = src_val
    dst_function = in
    # Offsets are just unit steps in four directions.
    offsets = [Address(0,1), Address(0,-1), Address(1,0), Address(-1,0)]

end

# COMPLEX BLOCKS
function build_processor_tile()
    # Working towards parameterizing this. For now, just leave this at two
    # because the "processor" components aren't parameterized for the number
    # of ports. This should be easy to fix though.
    num_links = 2
    # Create a new component for the processor tile
    # No need to set the primtiive class or metadata because we won't
    # be needing it.
    comp = Component("processor_tile") 
    # Add the circuit switched ports    
    directions = ("east", "north", "south", "west")
    for dir in directions
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
    add_child(comp, build_processor(), "processor")
    # Instantiate the directional routing muxes
    routing_mux = build_mux(5,1)
    for dir in directions
        name = join((dir, "_mux"))
        add_child(comp, routing_mux, name, num_links)
    end
    # Instantiate the muxes routing data to the fifos
    add_child(comp, build_mux(9,1), "fifo_mux", 2)

    # Interconnect - Don't attach metadata and let the routing routine fill in
    # defaults to intra-tile routing.
    connect_ports!(comp, "processor.memory_out", "memory_out")
    connect_ports!(comp, "memory_in", "processor.memory_in")
    
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
    # TODO: Throw this in a loop to make it easier to do.
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
    tile = build_processor_tile()
    # Need to add the memory processor attribute the the processor.
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
    component = Component("mux", primitive = "mux")
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
function build_processor()
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["processor"]
    component = Component("standard_processor", primitive = "", metadata = metadata)    
    # Add the input fifos
    add_port(component, "fifo", "input", 2)
    # Add the output ports
    for str in ("north", "east", "south", "west")
        add_port(component, str, "output", 2)
    end
    # Add the dynamic circuit switched network
    add_port(component, "dynamic", "output", 1)
    # Add memory ports. Will only be connected in the memory processor tile.
    add_port(component, "memory_in", "input")
    add_port(component, "memory_out", "output")
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
    add_port(component, "memory_in", "input", 2)
    add_port(component, "memory_out", "output", 2)
    # Return the created type
    return component
end

##############################
#      2 PORT MEMORY         #
##############################
function build_memory_2port()
    # Build a normal memory component and add the memory_2port attribute.
    component = build_memory_1port()
    push!(component.metadata["attributes"], "memory_2port")
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
    add_port(component, "circuit_out", "output", 2)
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
    add_port(component, "circuit_in", "output", 2)
    # Return the created type
    return component
end
