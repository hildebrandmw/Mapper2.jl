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

"""
    push_to_dict(d, k, v)

Push value `v` to the vector found in dictionary `d` at `d[k]`. If `d[k]`
does not exist, create a new vector by `d[k] = [v]`.
"""
function push_to_dict(d, k, v)
    haskey(d, k) ? push!(d[k], v) : d[k] = [v]
    return nothing
end

"""
    rev_dict(d)

Reverse the keys and values of dictionary `d`. Behavior if multiple values
are equivalent is not defined.
"""
rev_dict(d) = Dict(v => k for (k,v) in d)

"""
    condense(x)

Given a mutible collection `x`, make all equivalent values in `x` point to a
single instance in memory. If `x` is made up of many of the same arrays, this
can greatly decrease the amount of memory required to store `x`.
"""
function condense(x)
    d = Dict{eltype(x), eltype(x)}()
    for i in eachindex(x)
        if haskey(d, x[i])
            x[i] = d[x[i]]
        else
            d[x[i]] = x[i]
        end
    end
    return nothing
end

