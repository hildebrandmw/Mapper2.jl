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
getpathindex(l::Location) = l.pathindex
MapperCore.getaddress(c::CartesianIndex) = c
getpathindex(c::CartesianIndex) = 1

################################################################################
# Maptables
################################################################################

abstract type AbstractMapTable{D} end
struct MapTable{D} <: AbstractMapTable{D}
    task_classes        ::Vector{Int64}
    normal_class_map    ::Vector{Array{Vector{Int64},D}}
    special_class_map   ::Vector{Vector{Location{D}}}
end

struct FlatMapTable{D} <: AbstractMapTable{D}
    task_classes        ::Vector{Int64}
    normal_class_map    ::Vector{Array{Bool,D}}
    special_class_map   ::Vector{Vector{CartesianIndex{D}}}
end

function MapTable(
            arch::TopLevel{A,D}, 
            taskgraph, 
            component_table; 
            isflat = false,
           ) where {A,D}

    classes, normal_class_reps, special_class_reps = task_equivalence_classes(A, taskgraph)

    # For each normal node class C, create an array the same size as the 
    # component_table. For each address A, record the indices of the paths at
    # componant_table[A] that C can be mapped to.
    normal_class_map = map(normal_class_reps) do node
        map(component_table) do paths
            [index for (index,path) 
             in enumerate(paths) 
             if canmap(A, node, arch[path])]
        end
    end

    # For each special node class C, create a vector of Locations that
    # C can be mapped to.
    special_class_map = map(special_class_reps) do node
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
    # The special_class_map can be simplified to just hold the Address that
    # a class can be mapped to and not both an Address and a component index.
    if isflat
        normal_class_map = [map(!isempty, i) for i in normal_class_map]
        special_class_map = [map(getaddress, i) for i in special_class_map]

        return FlatMapTable(classes, normal_class_map, special_class_map)
    end
    return MapTable(classes, normal_class_map, special_class_map)
end

# Methods
isnormal(class::Int64) = class > 0


location_type(m::MapTable{D}) where D = Location{D}
location_type(m::FlatMapTable{D}) where D = Address{D}

function getlocations(m::MapTable{D}, class::Int, address::Address{D}) where D
    return [Location(address, i) for i in m.normal_class_map[class][address]]
end

function getlocations(m::FlatMapTable{D}, class::Int, address::Address{D}) where D
    return m.normal_class_map[class][address] ? [address] : Address{D}[]
end

function getlocations(m::AbstractMapTable{D}, node::Int) where D
    # Get the class for this 
    class = m.task_classes[node]
    if isnormal(class)
        locations = location_type(m)[]
        table = m.normal_class_map[class]
        @compat for address in CartesianIndices(table)
            append!(locations, getlocations(m, class, address))
        end
        return locations
    else
        return m.special_class_map[-class]
    end
end

function isvalid(m::MapTable, task_index::Integer, location::Location) 
    class = m.task_classes[task_index]
    if isnormal(class)
        component = getpathindex(location)
        list = m.normal_class_map[class][getaddress(location)]
        return in(component, list)
    else
        return in(location, m.special_class_map[-class])
    end
end

function isvalid(m::FlatMapTable, task_index::Integer, location::Address)
    class = m.task_classes[task_index]
    if isnormal(class)
        return m.normal_class_map[class][getaddress(location)]
    else
        return in(location, m.special_class_map[-class])
    end
end

@doc """
    isvalid(m::AbstractMapTable, task::Int, location::Union{Location,CartesianIndex})

Return `true` is node `task` can be mapped to `location`. 
""" isvalid
