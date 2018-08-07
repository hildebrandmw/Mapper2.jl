struct PathTable{D,T}
    table::Array{Union{T,Nothing},D}
end

# Case where no dimensional expansion is needed.
function PathTable(table::Array{Vector{T},D}, fullsize::NTuple{D}) where {T,D}
    return PathTable{D,T}([isempty(t) ? nothing : first(t) for t in table])
end

function PathTable(table::Array{Vector{T},D}, fullsize::NTuple{N}) where {T,D,N}
    newtable = map(CartesianIndices(fullsize)) do idx
        a = first(Tuple(idx))
        b = Base.tail(Tuple(idx))

        vector = table[b...]
        return checkbounds(Bool, vector, a) ? vector[a] : nothing
    end
    return PathTable{N,T}(newtable)
end

Base.getindex(p::PathTable, i...) = getindex(p.table, i...)

# Iterator protocol
Base.iterate(p::PathTable) = iterate(p.table)
Base.iterate(p::PathTable, state) = iterate(p.table, state)
Base.length(p::PathTable) = length(p.table)
Base.size(pathtable::PathTable) = size(pathtable.table)
Base.size(pathtable::PathTable, i) = size(pathtable.table, i)
Base.IteratorSize(p::PathTable) = Base.IteratorSize(p.table)

function findaddress(pathtable::PathTable{D}, address::Address{D}, item) where D
    @assert pathtable[address] == item
    return address
end

function findaddress(pathtable::PathTable, address::Address, item) where D
    for i in 1:size(pathtable, 1)
        if pathtable[i, address] == item
            return Address(i, address)
        end
    end
    throw(KeyError(item))
end

function build_pathtable(toplevel::TopLevel{D}, ruleset::RuleSet) where D
    offset = getoffset(toplevel)
    @debug "Architecture Offset: $offset"
    # Get the dimensions of the addresses to build the array that is going to
    # hold the component table. Get the inside tuple for creation.
    dims = size(toplevel)
    table = fill(Path{Component}[], dims...)

    for (name, component) in toplevel.children
        # Collect full paths for all components that are mappable.
        paths = [
            catpath(name, p)
            for p in walk_children(component)
            if ismappable(ruleset, component[p])
        ]

        # Account for toplevel to array address offset
        table[getaddress(toplevel, name) + offset] = paths
    end

    # Expand the table to full-size
    fulldims = MapperCore.fullsize(toplevel, ruleset)
    return PathTable(table, fulldims)
end
