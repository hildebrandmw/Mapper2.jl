@testset "Testing Address Type" begin
    # Do some tests on 1d addresses
    let
        # Create a 1d Address
        a = Address(1)
        # Make sure the tuple created is what is expected.
        @test a.addr == (0,)
        # Make sure address equality if working
        @test a == Address((0,))
        # Construct a 1d tuple again
        a = Address((1,))
        # Again, make sure address is working as expected.
        @test a.addr == (1,)
    end
    # 2D Addresses
    let
        a = Address(2)
        @test a == Address((0,0))
        @test Address(0,0) == Address((0,0))
        a = Address((1,2))
        b = Address((1,3))
        @test (a < b) == true
        @test (b < a) == false
        @test (a == b) == false
        b = Address((1,2))
        @test (a < b) == false
        @test (b > a) == false
        # Test the "maximum" function
        a = Address((10, 20))
        @test maximum(a) == 20
        
        # Test the iterator interface
        count = 0
        for (count,i) in enumerate(a)
            @test a == Address((10,20))
        end
        @test count == 1
    end
    # Test Address Arithmetic
    let
        a = Address((1,2,3))
        b = Address((4,5,6))
        @test a + b == Address((1+4, 2+5, 3+6))
        @test a - b == Address((1-4, 2-5, 3-6))
        @test a * b == Address((1*4, 2*5, 3*6))
    end
    #########################
    # Test addressing modes #
    #########################
    # Same dimensional addressing
    let
        arr = rand(2,2,2) 
        addr = Address((1,1,1))
        @test arr[addr] == arr[1,1,1]
        arr[addr] = 0.5
        @test arr[1,1,1] == 0.5
    end
    # Double dimensional addressing
    let
        arr = rand(3,3,3,3)
        a = Address((2,2))
        b = Address((3,1))
        @test arr[a,b] == arr[2,2,3,1]
        arr[a,b] = 0.5
        @test arr[2,2,3,1] == 0.5
        # Test the throwing of errors when array size is incorrect.
        barr = rand(3,3,3)
        @test_throws AssertionError getindex(barr,a,b)
        @test_throws AssertionError setindex!(barr,10.0,a,b)
    end
end
