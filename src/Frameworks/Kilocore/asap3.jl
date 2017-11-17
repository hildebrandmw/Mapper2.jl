function build_asap3(;A = KCBasic)
    # Start with a new component - clarify that it is 2 dimensional
    arch = TopLevel{A,2}("asap3")
    num_links = 2

    ####################
    # Normal Processor #
    ####################
    # Get a processor tile to instantiate.
    processor = build_processor_tile(num_links)
    # Instantiate it at the required addresses
    for r in 1:30, c in 2:33
        add_child(arch, processor, Address{2}(r,c))
    end
    for r in 31:32, c in 14:21
        add_child(arch, processor, Address{2}(r,c))
    end

	####################
	# Memory Processor #
	####################
	memory_processor = build_memory_processor_tile(num_links)
	# Instantiate it at the required addresses
	for r = 31, c = 2:13
        add_child(arch, memory_processor, Address{2}(r,c))
	end
	for r = 31, c = 22:33
        add_child(arch, memory_processor, Address{2}(r,c))
	end

	#################
	# 2 Port Memory #
	#################
	memory_2port = build_memory_2port()
	for r = 32, c in (2:2:12)
        add_child(arch, memory_2port, Address{2}(r,c))
	end
	for r = 32, c in (22:2:32)
        add_child(arch, memory_2port, Address{2}(r,c))
	end

	#################
	# Input Handler #
	#################
	input_handler = build_input_handler(num_links)
    add_child(arch, input_handler, Address{2}(1,1))

	##################
	# Output Handler #
	##################
	output_handler = build_output_handler(num_links)
    add_child(arch, output_handler, Address{2}(1,34))

	connect_processors(arch,num_links)
	connect_memories(arch)
	return arch
end
