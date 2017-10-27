function benchmark()
    # Any setup code goes here.
    m = build_asap4()
    # Run once, to force compilation.
    print_with_color(:light_red,
                     "\n======================= First run:\n",
                     bold = true)
    srand(666)
    @time routing_graph(m)

    # Run a second time, with profiling.
    #sa = SAStruct(testmap())
    print_with_color(:light_red,
                     "\n\n======================= Second run:\n",
                     bold = true)
    srand(666)
    Profile.init(delay=0.01)
    Profile.clear()
    Profile.clear_malloc_data()
    @profile @time routing_graph(m)

    # Write profile results to profile.bin.
    r = Profile.retrieve()
    f = open("profile.bin", "w")
    Profile.print(f)
    close(f)
end
