function Mapper2.ismappable(::Type{T}, c::Component) where {T <: Test3d}
    return search_metadata(c, "mappable", true)
end

function Mapper2.canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: Test3d}
    return Mapper2.ismappable(T, c)
end
