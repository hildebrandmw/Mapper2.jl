################################################################################
# Location data structure
################################################################################

# Data structure containing an Address and an index for a component slot.
struct Location{D}
    address     ::CartesianIndex{D}
    pathindex   ::Int64
end

Location{D}() where D = Location(zero(CartesianIndex{D}), 0)

# Overloads for accessing arrays of dimension D+1
Base.getindex(a::Array, l::Location) = a[l.pathindex, l.address]
Base.setindex!(a::Array, x, l::Location) = a[l.pathindex, l.address] = x

# Overloads for accessing Dicts of vectors.
function Base.getindex(a::Dict{Address{D},Vector{T}}, l::Location{D}) where {D,T}
    return a[l.address][l.component]
end

function Base.setindex!(a::Dict{Address{D},Vector{T}}, x, l::Location{D}) where {D,T}
    a[l.address][l.component] = x
end

MapperCore.getaddress(l::Location) = l.address
Base.getindex(l::Location) = l.pathindex
MapperCore.getaddress(c::CartesianIndex) = c
Base.getindex(c::CartesianIndex) = 1

################################################################################
# Maptables
################################################################################

abstract type AbstractMapTable{D} end

# Use to encode either a Flat Map or a Full Map.
#
# If the Map
struct MapTable{D,T,U} <: AbstractMapTable{D}
    normal    ::Vector{Array{T,D}}
    special   ::Vector{Vector{U}}

    # Inner constructor to enforce the following invariant:
    #
    # - If "T" is Vector{Int}, the "U" must be Location{D}.
    #
    # Explanation: This case represents the general case where each address has
    # multiple mapable components. the "Vector{Int}" records the index for this
    # address in the pathtable that a node can map to.
    #
    # Since we're recording both addresses and index into this Vector, we must
    # use "Location" types to encode this information.
    #
    #
    # - If "T" is Bool, the "U" must be CartesianIndex{D}
    #
    # Explanation: This happens during the "Flat Architecture optimization".
    # That is, each address only has one mappable component. Therefore, we don't
    # need a whole Vector{Int} encoding which index a node is mapped to, we only
    # need to store "true" if a node can be mapped to an address or "false" if
    # it cannot.

    function MapTable{D,T,U}(
            normal::Vector{Array{T,D}},
            special::Vector{Vector{U}}
        ) where {D,T,U}

        if T == Vector{Int}
            if U != Location{D}
                error("""
                    Expected parameter `U` to be `Location{D}`. Instead got $U
                    """)
            end
        elseif T == Bool
            if U != CartesianIndex{D}
                error("""
                    Expected parameter `U` to be `CartexianIndex{D}`. Instead got $U
                    """)
            end
        else
            error("Unacceptable parameter T = $T")
        end
        return new{D,T,U}(normal,special)
    end
end

function MapTable(
        normal::Vector{Array{T,D}},
        special::Vector{Vector{U}}
    ) where {T,D,U}
    return MapTable{D,T,U}(normal,special)
end

location_type(m::MapTable{D,T,U}) where {D,T,U}  = U


function MapTable(
        arch::TopLevel{A,D},
        equivalence_classes,
        component_table;
        isflat = false,
    ) where {A,D}


    # For each normal node class C, create an array the same size as the
    # component_table. For each address A, record the indices of the paths at
    # componant_table[A] that C can be mapped to.
    normal = map(equivalence_classes.normal_reps) do node
        map(component_table) do paths
            [index for (index,path) in enumerate(paths) if canmap(A, node, arch[path])]
        end
    end

    # For each special node class C, create a vector of Locations that
    # C can be mapped to.
    special = map(equivalence_classes.special_reps) do node
        locations_for_node = Location{D}[]
        @compat for address in CartesianIndices(component_table)
            for (index, path) in enumerate(component_table[address])
                if canmap(A, node, arch[path])
                    push!(locations_for_node, Location(address, index))
                end
            end
        end
        return locations_for_node
    end

    # Simplify data structures
    # If the length of each element of "component_table" is 1, then the elements
    # of the normal class map can just be boolean values.
    #
    # The special can be simplified to just hold the Address that
    # a class can be mapped to and not both an Address and a component index.
    if isflat
        normal = [map(!isempty, i) for i in normal]
        special = [map(getaddress, i) for i in special]

        return MapTable(normal, special)
    end
    return MapTable(normal, special)
end

function getlocations(m::MapTable{D,T,U}, class::Int) where {D,T,U}
    if isnormal(class)
        # Allocation an empty vector of the appropriate location type.
        locations = U[]
        table = m.normal[class]
        # Use @compat for this to get the "CartesianIndices" iterator.
        @compat for address in CartesianIndices(table)
            append!(locations, getlocations(m, class, address))
        end
        return locations
    else
        return m.special[-class]
    end
end

# MapTable methods

function getlocations(
        m::MapTable{D,Vector{Int}},
        class::Int,
        address::Address{D}
    ) where D
    return [Location(address, i) for i in m.normal[class][address]]
end

function getlocations(m::MapTable{D,Bool},class::Int,address::Address{D}) where D
    return m.normal[class][address] ? [address] : Address{D}[]
end

function isvalid(m::MapTable, class::Integer, location)
    if isnormal(class)
        component = getindex(location)
        list = m.normal[class][getaddress(location)]
        return in(component, list)
    else
        return in(location, m.special[-class])
    end
end

canhold(v::Vector) = length(v) > 0
canhold(b::Bool) = b

function isvalidaddress(m::MapTable, class::Integer, address::Address)
    if isnormal(class)
        return canhold(m.normal[class][address])
    else
        return in(location, m.special[-class])
    end
end

function genlocation(m::MapTable{D,Vector{Int}}, class::Integer, address::Address) where D
    # Assume that the class is a normal class. This will throw a runtime error
    # if used with a negative class.

    # Pick a random index in the collection of primitives at that address.
    return Location(address, rand(1:length(m.normal[class][address])))

end

genlocation(m::MapTable{D,Bool}, class, address) where D = address
