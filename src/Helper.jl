module Helper

using DocStringExtensions

# Manually reexport used names in DocStringExtensions
export  DOCSTRING,
        TYPEDEF,
        FIELDS,
        METHODLIST,
        SIGNATURES,
        @template

export  Address,
        emptymeta,
        wrap_vector,
        typeunion,
        push_to_dict,
        add_to_dict,
        rev_dict,
        rev_dict_safe,
        intern,
        rand_cartesian,
        dim_max,
        dim_min

# Convenience mapping
# TODO: Think about replacing this because it could cause confusion ... 
const Address = CartesianIndex

macro SetupDocStringTemplates()
    return esc(quote
        # Set up default template.
        @template DEFAULT = """
            $(DOCSTRING)
            """

        # Template for type definitions.
        @template TYPES = """
            $(TYPEDEF)

            Fields
            ------
            $(FIELDS)

            Documentation
            -------------
            $(DOCSTRING)

            Method List
            -----------
            $(METHODLIST)
            """
    end)
end

"Return an empty `Dict{Sring,Any}()` for `metadata` fields."
emptymeta() = Dict{String,Any}()

wrap_vector(v) = [v]
wrap_vector(v::Vector) = identity(v)

function typeunion(A::Array)
    types = unique(map(typeof, A))
    return Array{Union{types...}}(A)
end

"""
    push_to_dict(d, k, v)

Push value `v` to the vector found in dictionary `d` at `d[k]`. If `d[k]`
does not exist, create a new vector by `d[k] = [v]`.
"""
function push_to_dict(d::AbstractDict{K,V}, k, v) where {K,V}
    haskey(d, k) ? push!(d[k], v) : d[k] = V([v])
    return nothing
end

"""
    add_to_dict(d::Dict{K}, k::K, v = 1; b = 1) where K

Increment `d[k]` by `v`. If `d[k]` does not exist, initialize `d[k] = b`.
"""
add_to_dict(d, k, v = 1; b = 1)  = haskey(d, k) ? (d[k] += v) : (d[k] = b)

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

_dimop(x, op) = reduce(op, i.I for i in x)
dim_min(x) = _dimop(x, (a,b) -> min.(a,b))
dim_max(x) = _dimop(x, (a,b) -> max.(a,b))

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
