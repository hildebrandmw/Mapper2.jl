#=
Simple address type. Parameterized by the number of dimensions to explore
arbitrary dimensional architectures.
=#
abstract type AbstractAddress end

const __ADDR_REP = Int16
struct Address{N} <: AbstractAddress
    addr::NTuple{N, __ADDR_REP}
end

function Address(addr::NTuple{N,Int64}) where {N}
    x = convert.(__ADDR_REP, addr)
    return Address{N}(x)
end

function rand_address_impl(a::Type{T}, b::Type{T}) where T <: NTuple{N,Any} where N
    # Create the first entry
    ex = :($__ADDR_REP(rand(a[1]:b[1])))
    for i = 2:N
        ex = :($ex,$__ADDR_REP(rand(a[$i]:b[$i])))
    end
    # Construct the address type
    return :(Address{$N}($ex))
end

@generated function rand_address(a::NTuple{N}, b::NTuple{N}) where {N}
    return rand_address_impl(a,b)
end


function Address{N}(x::T...) where {N, T<:Integer}
    return Address{N}(__ADDR_REP.(x))
end

dimension(::Address{D}) where {D} = D

"""
Empty Constructors. Returns an address with each entry zero.
"""
Address{N}() where {N} = Address(Tuple(zero(__ADDR_REP) for ~ = 1:N))



"""
    Address{2}(r,c)

Return a 2d address with the given row and column.
"""
Address(r,c) = Address((r,c))

"""
    Address{3}(r,c,1)

Return a 3d address with the given row and column.
"""
Address(r,c,l) = Address((r,c,l))
Base.show(io::IO, a::Address) = print(io, "Address", a.addr)
Base.string(a::Address) = join(("Address", string(a.addr)))
################################################################################
# METHODS
################################################################################
# For comparison methods, just use the fallback methods of the underlying
# tuples
Base.isequal(a::Address{N}, b::Address{N}) where {N} = a.addr == b.addr
Base.isless(a::Address{N}, b::Address{N}) where {N} = a.addr < b.addr

# Hash functions
Base.hash(a::Address) = hash(a.addr)
Base.hash(a::Address, h::UInt64) = hash(a.addr, h)
Base.maximum(a::Address) = maximum(a.addr)

# Simple Iterator Interface.
Base.start(a::Address) = false
Base.next(a::Address, state::Bool) = (a, true)
Base.done(a::Address, state::Bool) = state

# Address Arithmetic
import Base: +,-,*
+(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .+ b.addr)
-(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .- b.addr)
*(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .* b.addr)

# Function to return the extreme addresses of a collection
function address_extrema(addresses)
    # Copy the first element of the address vector. 
    ex = first(addresses).addr
    for address in addresses
        ex = max.(ex, address.addr)
    end
    return Address(ex)
end

################################################################################
# Lookup Table Access Methods
################################################################################
# Indexing for 3 dimensional arrays

function Base.setindex!(A::AbstractArray{T,N}, v::T, a::Address{N}) where {T,N}
    A[a.addr...] = v
end

function Base.getindex(A::AbstractArray{T,N}, a::Address{N})::T where {T,N}
    A[a.addr...]
end

function Base.setindex!(A::AbstractArray{T,K}, v::T, a::Address{N}, b::Address{N}) where {T,K,N}
#    @assert K == 2N "Accessing array must be twice as large as the addresses"
    A[a.addr..., b.addr...] = v
end

function Base.getindex(A::AbstractArray{T,K}, a::Address{N}, b::Address{N}) where {T,K,N}
#    @assert K == 2N "Accessing array must be twice as large as the addresses"
    return A[a.addr..., b.addr...]
end

function Base.setindex!(A::AbstractArray{T,K}, v::T, i::Integer, a::Address{N}) where {T,K,N}
    A[i, a.addr...] = v
end

function Base.getindex(A::AbstractArray{T,K}, i::Integer, a::Address{N}) where {T,K,N}
    return A[i, a.addr...]
end
