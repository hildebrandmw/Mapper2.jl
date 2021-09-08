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
    getlocations(maptable, class::Int)

Return a vector of locations that nodes of type `class` can occupy.

Method List
-----------
$(METHODLIST)
"""
function getlocations end

"""
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

Parameters:
* `D` - The dimensionality of the `Addresses` in the table.
"""
struct MapTable{D} <: AbstractMapTable
    """
    Bit mask of whether a node class may be mapped to an address.

    Accessing strategy: Look up the node class to index the outer vector. Index the inner
    array with an address. 

    A `true` entry means the task class can be mapped.
    A `false` entry means the task calss cannot be mapped.
    """
    mask::Vector{Array{Bool,D}}
end

function MapTable(
    toplevel::TopLevel, ruleset::RuleSet, equivalence_classes, pathtable::PathTable{D}
) where {D}

    # For each node class C, create an array the same size as the
    # pathtable. For each address A, record the indices of the paths at
    # componant_table[A] that C can be mapped to.
    mask = map(equivalence_classes.reps) do node
        map(pathtable) do path
            return path !== nothing && canmap(ruleset, node, toplevel[path])
        end
    end
    return MapTable(mask)
end
location_type(::MapTable{D}) where {D} = Address{D}

# Makes repeated calls to the 3 argument version of getlocations starting at
# all base addresses to generate ALL locations for this class.
function getlocations(maptable::MapTable{D}, class::Int) where {D}
    # Allocation an empty vector of the appropriate location type.
    addresses = location_type(maptable)[]
    table = maptable.mask[class]

    for address in CartesianIndices(table)
        isvalid(maptable, class, address) && push!(addresses, address)
    end
    return addresses
end

function isvalid(maptable::MapTable, class::Integer, address::Address)
    return maptable.mask[class][address]
end
