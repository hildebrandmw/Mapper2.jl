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
struct MapTable{T,D} <: AbstractMapTable
    """
    Accessing methodology:

    For a node of class `class_idx`, `normal[class_index][address]` returns
    a `Vector{Int}` of component indices at `address` to which nodes of
    type `class_idx` may be mapped.

    If the flat architecture optimization is used, `normal[class_index][address]`
    returns a `Bool`, which is `true` if nodes of type `class_idx` may be
    mapped to the only mappable component at `address`.
    """
    normal :: Vector{Array{T,D}}
end

function MapTable(
        toplevel::TopLevel,
        ruleset::RuleSet,
        equivalence_classes,
        pathtable::PathTable{D},
    ) where {D}


    # For each normal node class C, create an array the same size as the
    # pathtable. For each address A, record the indices of the paths at
    # componant_table[A] that C can be mapped to.
    normal = map(equivalence_classes.reps) do node
        map(pathtable) do path
            return path !== nothing && canmap(ruleset, node, toplevel[path])
        end
    end
    return MapTable(normal)
end
location_type(::MapTable{Bool,D}) where {D} = Address{D}

# Makes repeated calls to the 3 argument version of getlocations starting at
# all base addresses to generate ALL locations for this class.
function getlocations(maptable::MapTable{T,D}, class::Int) where {T,D}
    # Allocation an empty vector of the appropriate location type.
    locations = location_type(maptable)[]
    table = maptable.normal[class]

    for address in CartesianIndices(table)
        append!(locations, getlocations(maptable, class, address))
    end
    return locations
end

function getlocations(
        maptable::MapTable{Bool,D},
        class::Int,
        address::Address{D}
    ) where D

    return maptable.normal[class][address] ? [address] : Address{D}[]
end

# Helpers for "isvalid"
# Top is for the general case, bottom is for the flat-optimization case.
canhold(b::Bool) = b

function isvalid(maptable::MapTable, class::Integer, address :: Address)
    maptable_entry = maptable.normal[class][address]
    return canhold(maptable_entry)
end
