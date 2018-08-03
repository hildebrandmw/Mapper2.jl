"""
Typed wrapper for `Vector{String}`.
"""
struct Path{T}
    steps   ::Vector{String}

    # Hooray for inner constructors!
    Path{T}() where T = new{T}(String[])
    function Path{T}(strings::Vector{<:AbstractString}) where T
        new{T}(String.(strings))
    end
end

function Path{T}(string::AbstractString) where T
    return isempty(string) ? Path{T}() : Path{T}(split(string, "."))
end
Path{T}(strings::AbstractString...) where T = Path{T}(collect(strings))


# only equal if types T are equal and steps are equal
Base.:(==)(::Path, ::Path) = false
Base.:(==)(a::Path{T}, b::Path{T}) where T = a.steps == b.steps

Base.hash(c::Path{T}, u::UInt64) where T = hash(c.steps, hash(T,u))

Base.length(p::Path) = length(p.steps)
Base.first(p::Path) = first(p.steps)
Base.last(p::Path) = last(p.steps)

# Methods for growing a path.
path_promote(::Type{T}, ::Type{T}) where T = T
path_demote(::Type{T}) where T = T

function catpath(a::Path{T}, b::Path{U}) where {T,U}
    return Path{path_promote(T,U)}(vcat(a.steps, b.steps))
end

catpath(a::String, b::Path{T}) where T = Path{T}(vcat(a, b.steps))

function striplast(a::Path{T}) where T
    length(a) == 0 && throw(BoundsError(a, 0))
    return Path{path_demote(T)}(a.steps[1:end-1])
end

function stripfirst(a::Path{T}) where T
    length(a) == 0 && throw(BoundsError(a, 0))
    return Path{T}(a.steps[2:end])
end

function splitpath(a::Path{T}, i::Integer) where T
    0 <= i <= length(a) || throw(BoundsError())
    
    pre = Path{path_demote(T)}(a.steps[1:end-i])
    post = Path{T}(a.steps[end+1-i:end])

    return pre,post
end

Base.show(io::IO, p::Path) = print(io, string(p))
Base.string(c::Path{T}) where T = "Path{$(string(T))} $(join(c.steps, "."))"
