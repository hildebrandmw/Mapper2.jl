function Mapper2.ismappable(::TestRuleSet, c::Component)
    return haskey(c.metadata, "task")
end
function Mapper2.isspecial(::TestRuleSet, t::TaskgraphNode)
    return in(t.metadata["task"], ("input","output"))
end
function Mapper2.isequivalent(::TestRuleSet, a::TaskgraphNode, b::TaskgraphNode)
    # Return true if the "required_attributes" are equal
    return a.metadata["task"] == b.metadata["task"]
end
function Mapper2.canmap(::TestRuleSet, t::TaskgraphNode, c::Component)
    haskey(c.metadata, "task") || return false
    return t.metadata["task"] == c.metadata["task"]
end
