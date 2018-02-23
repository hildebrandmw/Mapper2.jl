@testset "Testing Example 1" begin
    using Example1

    local m
    makemap     = true 
    placement   = true
    routing     = true
    # Try making a map
    try
        m = make_map()
    catch
        makemap = false
    end
    @test makemap

    # Try placement
    try
        m = place(m, move_attempts = 5000)
    catch
        placement = false
    end
    @test placement

    # Try routing
    try
        m = route(m)
    catch
        routing = false
    end
    @test routing

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
end
