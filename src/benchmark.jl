function benchmark()
    # Any setup code goes here.
    sa = SAStruct(testmap())
    # Run once, to force compilation.
    print_with_color(:light_red,
                     "\n======================= First run:\n",
                     bold = true)
    srand(666)
    @time place(sa, move_attempts = 10000)

    # Run a second time, with profiling.
    sa = SAStruct(testmap())
    print_with_color(:light_red,
                     "\n\n======================= Second run:\n",
                     bold = true)
    srand(666)
    Profile.init(delay=0.01)
    Profile.clear()
    Profile.clear_malloc_data()
    @profile @time place(sa, move_attempts = 10000)

    # Write profile results to profile.bin.
    r = Profile.retrieve()
    f = open("profile.bin", "w")
    Profile.print(f)
    close(f)
end
