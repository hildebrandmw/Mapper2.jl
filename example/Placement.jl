function Mapper2.ismappable(::Type{T}, c::Component) where {T <: TestArchitecture}
    return haskey(c.metadata, "task")
end
function Mapper2.isspecial(::Type{T}, t::TaskgraphNode) where {T <: TestArchitecture}
    return in(t.metadata["task"], ("input","output"))
end
function Mapper2.isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode) where {T <: TestArchitecture}
    # Return true if the "required_attributes" are equal
    return a.metadata["task"] == b.metadata["task"]
end
function Mapper2.canmap(::Type{T}, t::TaskgraphNode, c::Component) where {T <: TestArchitecture}
    haskey(c.metadata, "task") || return false
    return t.metadata["task"] == c.metadata["task"]
end
