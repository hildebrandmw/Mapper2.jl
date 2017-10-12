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

function push_to_dict(dict, k, v)
    haskey(dict, k) ? push!(dict[k], v) : dict[k] = [v]
    return nothing
end

rev_dict(d) = Dict(v => k for (k,v) in d)
