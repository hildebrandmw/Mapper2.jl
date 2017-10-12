function benchmark()
    # Any setup code goes here.
    sa = SAStruct(testmap())
    # Run once, to force compilation.
    println("======================= First run:")
    srand(666)
    @time place(sa)

    # Run a second time, with profiling.
    println("\n\n======================= Second run:")
    srand(666)
    Profile.init(delay=0.01)
    Profile.clear()
    Profile.clear_malloc_data()
    @profile @time place(sa)

    # Write profile results to profile.bin.
    r = Profile.retrieve()
    f = open("profile.bin", "w")
    Profile.print(f)
    close(f)
end
