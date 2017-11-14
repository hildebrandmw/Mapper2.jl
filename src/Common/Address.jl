#=
Simple address type. Parameterized by the number of dimensions to explore
arbitrary dimensional architectures.
=#
abstract type AbstractAddress end

const __ADDR_REP = Int16
struct Address{N} <: AbstractAddress
    addr::NTuple{N, __ADDR_REP}
end



"""
Empty Constructors. Returns an address with each entry zero.
"""
Address{N}() where {N} = Address(Tuple(zero(__ADDR_REP) for ~ = 1:N))
Address(x::NTuple{N,Int64}) where {N} = Address{N}(__ADDR_REP.(x))
Address(x::T...) where {T <: Integer} = Address{length(x)}(__ADDR_REP.(x))
Address{N}(x::T...) where {N, T<:Integer} = Address{N}(__ADDR_REP.(x))

#=
Function to efficientrly generate a random address given a tuple of lower bounds
and a tuple of upper bounds.
=#
function rand_address_impl(lb::Type{T}, ub::Type{T}) where T <: NTuple{N,Any} where N
    #=
    Push to the .args field - this will actually create a tuple.
    Originally - I was tryint to iteratively build an expression using the
    technique of:

    ex = :($ex, ...)

    But - this just ended up with this gnarly nested tuple thing like

    ((((...) ...) ...) ...)

    which is definitely not what I wanted. This way does what I want.
    =#
    
    # Create the first entry
    ex = :((rand(lb[1]:ub[1]),))
    for i = 2:N
        push!(ex.args, :(rand(lb[$i]:ub[$i])))
    end

    # Construct the address type
    return :(Address{$N}($ex))
end

@generated function rand_address(lb::NTuple{N}, ub::NTuple{N}) where {N}
    return rand_address_impl(lb,ub)
end

"""
    dimension(::Address{D}) where {D} = D

Quick methods for getting the dimension of an address
"""
dimension(::Address{D}) where {D} = D


Base.show(io::IO, a::Address) = print(io, "Address", a.addr)
Base.string(a::Address) = join(("Address", string(a.addr)))
################################################################################
# METHODS
################################################################################
# For comparison methods, just use the fallback methods of the underlying
# tuples
Base.isequal(a::Address{N}, b::Address{N}) where {N} = a.addr == b.addr
Base.isless(a::Address{N}, b::Address{N}) where {N} = a.addr < b.addr
function Base.isempty(a::Address{N}) where {N} 
    for i in a.addr
        i != 0 && return false
    end
    return true
end
# Hash functions - removed because not needed.
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
-(a::Address{N}) where {N} = Address(-1.*a.addr)

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
# TODO: Think about making these all @generated.
# Indexing for 3 dimensional arrays
function Base.setindex!(A::AbstractArray{T,N}, v::T, a::Address{N}) where {T,N}
    A[a.addr...] = v
end

function Base.getindex(A::AbstractArray{T,N}, a::Address{N})::T where {T,N}
    A[a.addr...]
end

function Base.setindex!(A::AbstractArray{T,K}, v::T, a::Address{N}, b::Address{N}) where {T,K,N}
    A[a.addr..., b.addr...] = v
end

function Base.getindex(A::AbstractArray{T,K}, a::Address{N}, b::Address{N}) where {T,K,N}
    A[a.addr..., b.addr...]
end

function Base.setindex!(A::AbstractArray{T,K}, v::T, i::Integer, a::Address{N}) where {T,K,N}
    A[i, a.addr...] = v
end

function Base.getindex(A::AbstractArray{T,K}, i::Integer, a::Address{N}) where {T,K,N}
    A[i, a.addr...]
end
