function build_asap3()
  # Start with a new component - clarify that it is 2 dimensional
  arch = TopLevel{2}("asap3")

  ####################
  # Normal Processor #
  ####################
  # Get a processor tile to instantiate.
  processor = build_processor_tile_kc1()
  # Instantiate it at the required addresses
  for r in 1:30, c in 2:33
      add_child(arch, processor, Address(r,c))
  end
  for r in 31:32, c in 14:21
      add_child(arch, processor, Address(r,c))
  end

	####################
	# Memory Processor #
	####################
	memory_processor = build_memory_processor_tile_kc1()
	# Instantiate it at the required addresses
	for r = 31, c = 2:13
		add_child(arch, memory_processor, Address(r,c))
	end
	for r = 31, c = 22:33
		add_child(arch, memory_processor, Address(r,c))
	end

	#################
	# 2 Port Memory #
	#################
	memory_2port = build_memory_2port()
	for r = 32, c in (2:2:12)
		 add_child(arch, memory_2port, Address(r,c))
	end
	for r = 32, c in (22:2:32)
		 add_child(arch, memory_2port, Address(r,c))
	end

	#################
	# Input Handler #
	#################
	input_handler = build_input_handler()
	add_child(arch, input_handler, Address(1,1))

	##################
	# Output Handler #
	##################
	output_handler = build_output_handler()
	add_child(arch, output_handler, Address(1,34))

	connect_processors(arch)
	connect_memories(arch)
	return arch

end

function build_processor_tile_kc1()

  num_links = 2
  # Create a new component for the processor tile
  # No need to set the primtiive class or metadata because we won't
  # be needing it.
  comp = Component("processor_tile")
  # Add the circuit switched ports
  directions = ("east", "north", "south", "west")
  for dir in directions
     for (suffix,class) in zip(("_in", "_out"), ("input", "output"))
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
  # Instantiate the xbar
	routing_mux = build_mux(5,5)
	name = "xbar"
	add_child(comp, routing_mux, name, num_links)
	# Interconnect - Don't attach metadata and let the routing routine fill in
	# defaults to intra-tile routing.
	connect_ports!(comp, "processor.memory_out", "memory_out")
	connect_ports!(comp, "memory_in", "processor.memory_in")
	# connect xbar i/o with processor i/o
	for i = 0:num_links-1
		connect_ports!(comp, string("processor.cs_out[",i,"]"), string("xbar[",i,"].in[0]"))
		connect_ports!(comp, string("xbar[",i,"].out[0]"), string("processor.cs_in[",i,"]"))
	end
	# connect xbar i/o with processor tile i/o
	count = 0
	for dir in directions
		count += 1
		for i = 0:num_links-1
			connect_ports!(comp, string("xbar[",i,"].out[",count,"]"), string(dir,"_out[",i,"]"))
			connect_ports!(comp, string(dir,"_in[",i,"]"), string("xbar[",i,"].in[",count,"]"))
		end
	end
	return comp

end

function build_memory_processor_tile_kc1()
    # Get a normal processor and add the memory ports to it.
    tile = build_processor_tile_kc1()
    # Need to add the memory processor attribute the the processor.
    push!(tile.children["processor"].metadata["attributes"], "memory_processor")
    return tile
end

##############################
#        PROCESSOR
##############################
"""
	build_processor_kc1()

Build a simple kc1 processor
"""
function build_processor_kc1()
	# Build the metadata dictionary for the processor component
	metadata = Dict{String,Any}()
	metadata["attributes"] = ["processor"]
	component = Component("standard_processor", primitive = "", metadata = metadata)
	# Add the processor cs input port
	add_port(component, "cs_in", "input", 2)
	# Add the processor cs output port
	add_port(component, "cs_out", "output", 2)
	# Add memory ports. Will only be connected in the memory processor tile.
	add_port(component, "memory_in", "input")
	add_port(component, "memory_out", "output")
	# Return the created type
	return component
end
