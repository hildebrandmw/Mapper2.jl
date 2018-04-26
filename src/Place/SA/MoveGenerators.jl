# AbstractMoveGenerator interface
const _AMV_API = (:getlinear, :getoffset)

"""
    AbstractMoveGenerator{D}

Generator type for selecting which processor index to attempt to move as well as
generate an offset in a given dimension.

Parameter `D::Int` indicates the dimension of the Generator.

Required API: $(make_ref_list(_AMV_API)).
"""
abstract type AbstractMoveGenerator{D} end

@doc """
    getlinear(a::AbstractMoveGenerator{D}, ub::Int)

Return a "random" number from 1 to `ub`.
""" getlinear

@doc """
    getoffset(a::AbstractMoveGenerator{D}, limit::Int)

Return a `D` dimensional CartesianIndex where each entry is in `[-limit,limit]`
"""

################################################################################
#  RandomGenerator
################################################################################
"""
    RandomGenerator{D}

Naive implementation. Simply uses `rand` to satisfy the required API.
"""
struct RandomGenerator{D} <:AbstractMoveGenerator{D} end

# Use rand() on the range 1:ub.
getlinear(::RandomGenerator, ub::Int) = rand(1:ub)

# Use rand() for each component of the returned vector
@generated function MapperCore.getoffset(::RandomGenerator{D}, limit) where D
    ex = [:(rand(-limit:limit)) for i in 1:D]
    return quote
        CartesianIndex{D}($(ex...))
    end
end

################################################################################
# SubRandomGenerator
################################################################################
"""
    SubRandomGenerator{D,V}

Generator for "subrandom" numbers, or a low-discrepancy sequency. Basically,
numbers generated for a given interval will still be uniformly distributed, but
will not exhibit the clustering that is common when using pure random algorithms.

This implementation generates numbers using the Additive sequence technique
described at [https://en.wikipedia.org/wiki/Low-discrepancy_sequence#Additive_recurrence].
"""
mutable struct SubRandomGenerator{D,V} <: AbstractMoveGenerator{D}
    # For choosing which processor to move.
    lin_adder   ::Float64 
    lin_value   ::Float64 
    # For picking a new address
    adders::NTuple{D,Float64}
    values::V
end

function SubRandomGenerator{D}() where D
    # Initialize linear adder to random "irrational"
    lin_adder = (sqrt(5)-1)/2
    # Randomize the starting point.
    lin_value = rand()

    # We will use the first D primes as multipliers for D dimensional operations
    p = [2]
    while length(p) < D
        push!(p, nextprime(1 + last(p)))
    end
    adders = Tuple(mod.(sqrt.(p),1))
    values = MVector{D}(rand(D))

    return SubRandomGenerator(
        lin_adder,
        lin_value,
        adders,
        values,
    )
end

# Add the stored value to the additive value. Since we ensure that lin_value
# is always between 0 and 1.0, we can perform the modularity check by simply
# comparing the new value to 1.0 and subtracting 1.0 if it is greater.
function getlinear(m::SubRandomGenerator, ub::Int)
    temp = m.lin_value + m.lin_adder
    new_value = temp > 1.0 ? temp - 1.0 : temp
    m.lin_value = new_value
    # Scale the new number from a range (0,1] to a range (0,ub] and take the 
    # ceiling to get a number on [1,ub]
    return ceil(Int64, ub*new_value)
end

# Helper expression generation function for getoffset.
function splat_update(n)
    return map(1:n) do i
        :(temp = m.values[$i] + m.adders[$i];
          m.values[$i] = temp > 1.0 ? temp - 1.0 : temp)
    end
end

# Helper expression generation function for getoffset.
function create_offset(n)
    return [:(ceil(Int64, mul * m.values[$i]) - limit - 1) for i in 1:n]
end

# This basically does the same thing as the linear operation, but after the
# multiplicative size scaling subtracts an offset to get a result on the
# range [-limit, limit].
@generated function MapperCore.getoffset(m::SubRandomGenerator{D}, limit::Int) where D
    val_update = splat_update(D)
    ret_val = create_offset(D)
    return quote
        # Add each value to its corresponding adder - resize to (0,1] if needed.
        $(val_update...)
        # We generate a number on [1,2*limit+1] using the technique for the
        # linear number, then we subtract (limit+1) to turn this into a number
        # on [-limit, limit]. Drop all of these into a CartesianIndex.
        mul = 2*limit + 1
        return CartesianIndex{D}($(ret_val...))
    end
end
