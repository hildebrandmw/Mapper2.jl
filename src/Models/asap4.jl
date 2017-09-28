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
end

# COMPLEX BLOCKS
function build_processor_tile()
    # Create a new component for the processor tile
    # No need to set the primtiive class or metadata because we won't
    # be needing it.
    comp = Component("processor_tile") 
    # Add the circuit switched ports    
    directions = ("east", "north", "south", "west")
    for dir in directions
        for (suffix,class)  in zip(("_in", "_out"), ("input", "output"))
            port_name = join((dir, suffix))
            add_port(comp, port_name, class, 2)
        end
    end
    # Instantiate the processor primitive 
    add_child(comp, build_processor(), "processor")
    # Instantiate the directional routing muxes
    routing_mux = build_mux(5,1)
    for dir in directions
        name = join((dir, "_mux"))
        add_child(comp, routing_mux, name, 2)
    end
    # Instantiate the muxes routing data to the fifos
    add_child(comp, build_mux(9,1), "fifo_mux", 2)

    return comp
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
    add_port(component, "in", "input")
    add_port(component, "out", "output")
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
    # Return the created type
    return component
end
  

##############################
#     MEMORY PROCESSOR
##############################
"""
    build_memory_processor()

Build a simple memory processor.
"""
function build_memory_processor()
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["processor", "memory_processor"]
    component = Component("memory_processor", primitive = "", metadata = metadata)    
    # Add the input fifos
    add_port(component, "fifo", "input", 2)
    add_port(component, "memory_in", "input", 1)
    # Add the output ports
    for str in ("north", "east", "south", "west")
        add_port(component, str, "output", 2)
    end
    # Add the dynamic circuit switched network
    add_port(component, "dynamic", "output", 1)
    add_port(component, "memory_out", "output", 1)
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
    add_port(component, "memory_in", "input", 1)
    add_port(component, "memory_out", "output", 1)
    # Return the created type
    return component
end

##############################
#      2 PORT MEMORY 
##############################
function build_memory_2port()
    # Build the metadata dictionary for the processor component
    metadata = Dict{String,Any}()
    metadata["attributes"] = ["memory_1port", "memory_2port"]
    component = Component("memory_2port", primitive = "", metadata = metadata)    
    # Add the input and output ports
    add_port(component, "memory_in", "input", 2)
    add_port(component, "memory_out", "output", 2)
    # Return the created type
    return component
end

##############################
#       INPUT HANDLER 
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
#       OUTPUT HANDLER 
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
