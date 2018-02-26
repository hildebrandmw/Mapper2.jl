module Helper

export  oneofin,
        typeunion,
        push_to_dict,
        add_to_dict,
        rev_dict,
        rev_dict_safe,
        intern,
        rand_cartesian,
        dim_max,
        dim_min,
        max_entry

"""
    oneofin(a, b)

Return `true` if at least one element of collection `a` is in collection `b`.
"""
function oneofin(a, b)
   for i in a
      in(i, b) && return true
   end
   return false
end

function typeunion(a::Array{T,N}) where {T,N}
    types = DataType[]
    for i in a
        t = typeof(i)
        if t ∉ types
            push!(types, t)
        end
    end
    return Array{Union{types...},N}(a)
end

"""
    push_to_dict(d, k, v)

Push value `v` to the vector found in dictionary `d` at `d[k]`. If `d[k]`
does not exist, create a new vector by `d[k] = [v]`.
"""
function push_to_dict(d, k, v)
    haskey(d, k) ? push!(d[k], v) : d[k] = valtype(d)([v]) 
    return nothing
end

"""
    add_to_dict(d::Dict{K}, k::K, v = 1; b = 1) where K

Increment `d[k]` by `v`. If `d[k]` does not exist, initialize `d[k] = b`.
"""
function add_to_dict(d, k, v = 1; b = 1)
    haskey(d, k) ? d[k] += v : d[k] = b
end

"""
    rev_dict(d)

Reverse the keys and values of dictionary `d`. Behavior if multiple values
are equivalent is not defined.
"""
rev_dict(d) = Dict(v => k for (k,v) in d)

"""
    rev_dict_safe(d::Dict{K,V}) where {K,V}

Reverse the keys and values of dictionary `d`. Returns a dictionary of type
`Dict{V, Vector{K}}` to handle the case where the same value in `d` points to
multiple keys.
"""
function rev_dict_safe(d::Dict{K,V}) where {K,V}
    r = Dict{V, Vector{K}}()
    for (k,v) in d
        push_to_dict(r, v, k)
    end
    return r
end

"""
    intern(x)

Given a mutable collection `x`, make all equivalent values in `x` point to a
single instance in memory. If `x` is made up of many of the same arrays, this
can greatly decrease the amount of memory required to store `x`.
"""
function intern(x)
    d = Dict{eltype(x), eltype(x)}()
    for i in eachindex(x)
        haskey(d, x[i]) ? (x[i] = d[x[i]]) : (d[x[i]] = x[i])
    end
    return nothing
end

################################################################################
# Cartesian Index Schenanigans
################################################################################
function _rand_cart(lb::Type{T}, ub::Type{T}) where T <: NTuple{N,Any} where N
    # Chain together a bunch of calls to rand
    ex = [:(rand(lb[$i]:ub[$i])) for i in 1:N]
    # Construct the address type
    return :(CartesianIndex{N}($(ex...)))
end

@generated function rand_cartesian(lb::NTuple{N}, ub::NTuple{N}) where {N}
    return _rand_cart(lb,ub)
end

max_entry(c::CartesianIndex) = maximum(c.I)

for (name, op) in zip((:dim_max, :dim_min), (:max, :min))
    eval(quote
        function ($name)(indices)
            # Copy the first element of the address iterator.
            ex = first(indices).I
            for index in indices
                ex = ($op).(ex, index.I)
            end
            return ex
        end
    end)
end

# Documentation for the max and min functions generated above.
@doc """
    `dim_max(indices)` returns tuple of the minimum componentwise values 
    from a collection of CartesianIndices.
    """ dim_max

@doc """
    `dim_min(indices)` returns tuple of the minimum componentwise values 
    from a collection of CartesianIndices.
    """ dim_min


end # module Helper
