@testset "Testing Whole Flow" begin
    using Example
    local m
    passed = true 
    try
        m = make_map()
        m = place(m)
        m = route(m)
    catch
        passed = false
    end
    @test passed
end
