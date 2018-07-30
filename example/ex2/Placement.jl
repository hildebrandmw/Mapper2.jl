function Mapper2.ismappable(::Test3d, c::Component)
    return search_metadata(c, "mappable", true)
end

function Mapper2.canmap(T::Test3d, t::TaskgraphNode, c::Component)
    return Mapper2.ismappable(T, c)
end
