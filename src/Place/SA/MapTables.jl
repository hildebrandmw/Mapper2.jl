################################################################################
# Location data structure
################################################################################
struct Location{D}
    address     ::CartesianIndex{D}
    component   ::Int64
end

Location{D}() where D = Location(zero(CartesianIndex{D}), 0)

Base.getindex(a::Array, l::Location) = a[l.component, l.address]
Base.setindex!(a::Array, x, l::Location) = a[l.component, l.address] = x

MapperCore.getaddress(l::Location) = l.address
getcomponent(l::Location)          = l.component
MapperCore.getaddress(c::CartesianIndex)   = c
getcomponent(c::CartesianIndex) = 1

################################################################################
# Maptables
################################################################################

abstract type AbstractMapTable{D} end
struct MapTable{D} <: AbstractMapTable{D}
    class       ::Vector{Int64}
    normal_lut  ::Vector{Array{Vector{Int64},D}}
    special_lut ::Vector{Vector{Location{D}}}
end

struct FlatMapTable{D} <: AbstractMapTable{D}
    class       ::Vector{Int64}
    normal_lut  ::Vector{Array{Bool,D}}
    special_lut ::Vector{Vector{CartesianIndex{D}}}
end

function MapTable(arch::TopLevel{A}, taskgraph, component_table; isflat = false) where A
    classes, normal_class_reps, special_class_reps = equivalence_classes(A, taskgraph)

    normal_lut = build_normal_lut(arch, normal_class_reps, component_table)
    special_lut = build_special_lut(arch, special_class_reps, component_table)

    # Simplify data structures
    if isflat
        normal_lut = [map(x -> length(x) > 0, i) for i in normal_lut]
        special_lut = [map(x -> getaddress(x), i) for i in special_lut]

        return FlatMapTable(classes, normal_lut, special_lut)
    end
    return MapTable(classes, normal_lut, special_lut)
end

# Methods
isnormal(class::Int64) = class > 0

ltype(m::MapTable{D}) where D = Location{D}
ltype(m::FlatMapTable{D}) where D = CartesianIndex{D}

function getlocations(m::MapTable{D}, table, address::CartesianIndex{D}) where D
    location = Location{D}[]
    for i in table[address]
        push!(location, Location(address,i))
    end
    return location
end

function getlocations(m::FlatMapTable{D}, table, address::CartesianIndex{D}) where D
    return table[address] ? [address] : CartesianIndex{D}[]
end

function getlocations(m::AbstractMapTable{D}, node::Int) where D
    # Get the class for this 
    class = m.class[node]
    if isnormal(class)
        locations = ltype(m)[]
        table = m.normal_lut[class]
        @compat for address in CartesianIndices(table)
            append!(locations, getlocations(m, table, address))
        end
        return locations
    else
        return m.special_lut[-class]
    end
end

function isvalid(m::MapTable,index,location::Location) 
    class = m.class[index]
    if isnormal(class)
        component = getcomponent(location)
        list = m.normal_lut[class][getaddress(location)]
        return component in list
    else
        return location in m.special_lut[-class]
    end
end

function isvalid(m::FlatMapTable, index, location::CartesianIndex)
    class = m.class[index]
    if isnormal(class)
        return m.normal_lut[class][getaddress(location)]
    else
        return location in m.special_lut[-class]
    end
end

@doc """
    isvalid(m::AbstractMapTable, index::Int, location::Union{Location,CartesianIndex})

Return `true` is node `index` can be mapped to `location`. 
""" isvalid
