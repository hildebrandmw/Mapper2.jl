@testset "Testing Example 1" begin
    using Example1

    local m
    makemap     = true 
    placement   = true
    routing     = true
    # Try making a map
    m = Example1.make_map()

    # Try placement
    m = Example1.place(m, move_attempts = 5000)

    # Try routing
    m = Example1.route(m)

    # Get statistics from the map
    MapperCore.report_routing_stats(m)

    expected_links = 12
    hist = MapperCore.global_link_histogram(m)
    # Get the number of global links from this
    found_links = 0
    for (k,v) in hist
        found_links += k*v
    end
    @test found_links == expected_links 
    @test MapperCore.check_routing(m)
end

@testset "Testing Example 2" begin
    using Example2

    local m
    makemap     = true 
    placement   = true
    routing     = true
    # Try making a map
    try
        m = Example2.make_map()
    catch
        makemap = false
    end
    @test makemap

    # Try placement
    try
        m = Example2.place(m)
    catch
        placement = false
    end
    @test placement

    # Try routing
    try
        m = Example2.route(m)
    catch
        routing = false
    end
    @test routing

    # Get statistics from the map
    MapperCore.report_routing_stats(m)
    # expect routing to fail because of inadequate resources.
    @test MapperCore.check_routing(m) == false
end
