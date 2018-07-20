################################################################################
# Location data structure
################################################################################

struct Location{D}
    address     ::CartesianIndex{D}
    pathindex   ::Int64
end

Location{D}() where D = Location(zero(CartesianIndex{D}), 0)
Base.zero(::Type{Location{D}}) where D = Location{D}()

# Overloads for accessing arrays of dimension D+1
@propagate_inbounds Base.getindex(a::Array, l::Location) = a[l.pathindex, l.address]
@propagate_inbounds Base.setindex!(a::Array, x, l::Location) = a[l.pathindex, l.address] = x

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

"""
TODO

API
---
* [`location_type`](@ref)
* [`getlocations`](@ref)
* [`isvalid`](@ref)
* [`genlocation`](@ref)


Implementations
---------------
* [`MapTable`](@ref)
"""
abstract type AbstractMapTable end

#######
# API #
#######

"""
Return the stored location type for a `MapTable`.

Method List
-----------
$(METHODLIST)
"""
function location_type end

"""
    getlocations(maptable, class::Int, [address])

Return a vector of locations that nodes of type `class` can occupy. If optional
argument `address` is provided, the list of locations will be restricted to
that address.

Method List
-----------
$(METHODLIST)
"""
function getlocations end

"""
    isvalid(maptable, class, location :: Location)

Return `true` if nodes of type `class` can occupy `location`.

    isvalid(maptable, class, address :: Address)

Return `true` if nodes of type `class` can occupy `address`. In other words, 
there is some component at `adddress` that class can be mapped to.

Method List
-----------
$(METHODLIST)
"""
function isvalid end

"""
    genlocation(maptable, class, address)

Return a random location that nodes of type `class` can occupy at `address`.
"""
function genlocation end

################################################################################
# MapTable
################################################################################

"""
Default implementation of [`AbstractMapTable`](@ref)

Important Parameters:
* `D` - The dimensionality of the `Addresses` in the table.
* `U` - The location type contained in the table. Will either be `Location{D}`
    if a generic placement is being used, or `CartesianIndex{D}` if the 
    flat-architecture optimization is used.
"""
struct MapTable{D,T,U} <: AbstractMapTable
    """
    Container for nodes classified as `normal`.

    Accessing methodology:

    For a node of class `class_idx`, `normal[class_index][address]` returns
    a `Vector{Int}` of component indices at `address` to which nodes of
    type `class_idx` may be mapped.

    If the flat architecture optimization is used, `normal[class_index][address]`
    returns a `Bool`, which is `true` if nodes of type `class_idx` may be 
    mapped to the only mappable component at `address`.
    """
    normal :: Vector{Array{T,D}}

    """
    Container for nodes classified as `special`.

    Accessing methodology:

    For a node of special class `class_idx`, `special[-class_idx]` returns a 
    vector `V` of locations that this node can occupy.
    """
    special :: Vector{Vector{U}}

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


function MapTable(
        toplevel::TopLevel{A,D},
        equivalence_classes,
        pathtable;
        isflat = false,
    ) where {A,D}


    # For each normal node class C, create an array the same size as the
    # pathtable. For each address A, record the indices of the paths at
    # componant_table[A] that C can be mapped to.
    normal = map(equivalence_classes.normal_reps) do node
        map(pathtable) do paths
            [index 
             for (index,path) in enumerate(paths) 
             if canmap(A, node, toplevel[path])
            ]
        end
    end

    # For each special node class C, create a vector of Locations that
    # C can be mapped to.
    special = map(equivalence_classes.special_reps) do node
        locations_for_node = Location{D}[]
        for address in CartesianIndices(pathtable)
            for (index, path) in enumerate(pathtable[address])
                if canmap(A, node, toplevel[path])
                    push!(locations_for_node, Location(address, index))
                end
            end
        end
        return locations_for_node
    end

    # Simplify data structures
    # If the length of each element of "pathtable" is 1, then the elements
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


location_type(maptable::MapTable{D,T,U}) where {D,T,U}  = U

# Handles both the general and flat architecture cases.
#
# Makes repeated calls to the 3 argument version of getlocations starting at
# all base addresses to generate ALL locations for this class.
function getlocations(maptable::MapTable{D,T,U}, class::Int) where {D,T,U}
    if isnormal(class)
        # Allocation an empty vector of the appropriate location type.
        locations = U[]
        table = maptable.normal[class]

        for address in CartesianIndices(table)
            append!(locations, getlocations(maptable, class, address))
        end
        return locations
    else
        return maptable.special[-class]
    end
end

# For the general case.
function getlocations(
        maptable::MapTable{D,Vector{Int}},
        class::Int,
        address::Address{D}
    ) where D
    return [Location(address, i) for i in maptable.normal[class][address]]
end

# For the flat architecure optimization.
function getlocations(
        maptable::MapTable{D,Bool},
        class::Int,
        address::Address{D}
    ) where D

    return maptable.normal[class][address] ? [address] : Address{D}[]
end

# Helpers for "isvalid"
# Top is for the general case, bottom is for the flat-optimization case.
canhold(v::Vector, i) = in(i, v)
canhold(v::Vector) = length(v) > 0
canhold(b::Bool) = b

function isvalid(maptable::MapTable, class::Integer, location :: Location)
    if isnormal(class)
        maptable_entry = maptable.normal[class][getaddress(location)]
        return canhold(maptable_entry, getindex(location))
    else
        return in(location, maptable.special[-class])
    end
end

function isvalid(maptable::MapTable, class::Integer, address :: Address)
    if isnormal(class)
        maptable_entry = maptable.normal[class][address]
        return canhold(maptable_entry)
    else
        return in(address, maptable.special[-class])
    end
end

# General case. Index into maptable using using the class and address.
#
# Pick a random element from the list of indices and create a Location out of
# it.
function genlocation(
        maptable::MapTable{D,Vector{Int}}, 
        class::Integer, 
        address::Address
    ) where D
    # Assume that the class is a normal class. This will throw a runtime error
    # if used with a negative class.

    # Pick a random index in the collection of primitives at that address.
    return Location(address, rand(1:length(maptable.normal[class][address])))

end

# If the flat architecture optimization is being used - no need to pick a 
# random component from the vector. The address istself is what's needed.
genlocation(m::MapTable{D,Bool}, class, address) where D = address
