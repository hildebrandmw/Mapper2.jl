# Control the move generation used by the Annealing scheme.
abstract type AbstractMoveGenerator end

# Document the interface for an AbstractMoveGenerator.
"""
    generate_move(sa_struct, move_generator, node_idx)

Generate a valid for move for the node with index `node_idx` in `sa_struct`.
If `isflat(sa_struct) == true`, return `CartesianIndex{D}` where 
`D = dimension(sa_struct)`. Otherwise, return `Location{D}`.
"""
function generate_move end

"""
    distancelimit(move_generator, sa_struct)

Return the maximum move distance of `move_generator` for `sa_struct`.
""" 
function distancelimit end

"""
    initialize!(move_generator, sa_struct, [limit = distancelimit(move_generator, sa_struct)])

Initialize the state of `move_generator` based on `sa_struct`. Common operations
include establishing an initial move distance limit or caching a list of 
possible moves.

If an initial limit is not supplied, it defaults to the maximum limit of
the move generator for the given architecture.
"""
function initialize!(move_generator, sa_struct)
    initialize!(move_generator, sa_struct, distancelimit(move_generator, sa_struct))
end

"""
    update!(move_generator, sa_struct, limit)

Update the move generator to a new move distance limit.
"""
function update! end

# Top level function - serves as entry point for the methods listed above.
@propagate_inbounds function generate_move!(
            sa_struct :: SAStruct{A}, 
            move_generator :: AbstractMoveGenerator,
            move_cookie,
        ) where {A <: Architecture}

    # Pick a random address
    node_idx = rand(1:length(sa_struct.nodes))

    new_location = generate_move(sa_struct, move_generator, node_idx)
    return move_with_undo(sa_struct, move_cookie, node_idx, new_location)
end


################################################################################
# Search Move Generator
################################################################################
"""
Move generator that operates by generating a random addresses where each 
component of the address is within `limit` of the old address.
"""
mutable struct SearchMoveGenerator{D} <: AbstractMoveGenerator 
    """
    The component-wise upperbound of the grid of the SAStruct. This is here
    to ensure that generated moves are within the total bounds of the SAStruct
    to improve the quality of move generation.
    """
    upperbound :: NTuple{D, Int}

    """
    The current distance limit.
    """
    limit :: Int    

    # Initialize an empty D dimensional SearchMoveGenerator
    SearchMoveGenerator{D}() where {D} = new(Tuple(0 for _ in 1:D), 0)
end

# Helpful constructor - extract "D" from the generating SAStruct
SearchMoveGenerator(sa_struct :: SAStruct{A,U,D}) where {A,U,D} = 
    SearchMoveGenerator{D}()


function initialize!(move_generator::SearchMoveGenerator, sa_struct::SAStruct, limit)
    move_generator.upperbound = size(sa_struct.pathtable)
    move_generator.limit = limit
    return nothing 
end
function update!(move_generator::SearchMoveGenerator, sa_struct :: SAStruct, limit)
    move_generator.limit = limit
end

# Take the largest single dimension of the parent SAStruct.
distancelimit(::SearchMoveGenerator, sa_struct) = maximum(size(sa_struct.pathtable))

# Some @generated function trickery to build an expression that generates an
# address where each component is within "limit" argument "address"
#
# Add some extra logic to clamp the result betwwen 1 and the upper bound of each
# component.
@generated function genaddress(
        address::CartesianIndex{D}, 
        limit, 
        upperbound
    ) where D

    ex = map(1:D) do i
        :(rand(max(1,address.I[$i] - limit):min(upperbound[$i], address.I[$i] + limit)))
    end
    return :(CartesianIndex{D}($(ex...)))
end

# Move generation in the general case.
@propagate_inbounds function generate_move(
        sa_struct::SAStruct{A}, 
        move_generator::SearchMoveGenerator,
        node_idx :: Int,
    ) where {A <: Architecture} 

    # Get the node at this index.
    node = sa_struct.nodes[node_idx]
    old_address = getaddress(node)
    maptable = sa_struct.maptable
    # Get the equivalent class of the node
    class = getclass(node)
    # Get the address and component to move this node to
    if isnormal(class)
        # Generate offset and check bounds.
        address = genaddress(
            old_address, 
            move_generator.limit, 
            move_generator.upperbound
        )

        # If the generated address is not valid, abort this move by just 
        # returning the old address.
        if !isvalid(maptable, class, address) 
            address = old_address
        end
        new_location = genlocation(maptable, class, address)
    else
        new_location = rand(maptable.special[-class])
    end

    # Return the new location for this node.
    return new_location
end


################################################################################
# Cached Move Generator
################################################################################

# The idea for this data structure is that the Locations or Addresses within
# some distance D of each Location/Address is precomputed. When the distance
# limit changes, this structure will have to be modified - hence why it's
# mutable.

"""
Look-up table for moves for a single node class starting at some base address.

The main invariant of this a MoveLUT ``L`` is with base address ``\\alpha`` is

```math
\\text{distance}\\left( L_\\text{targets}[i] - \\alpha \\right) \\leq \\delta \
    \\, \\forall i \\in 1 \\ldots L_\\text{idx}
```

where ``\\text{distance}`` is the distance between to addresses in the SAStruct
and `\\delta` is the current move distance limit.

Thus, to generate a random move within ``\\delta`` of ``\\alpha``, we must
need to perform the operation
```
L.targets[rand(1:L.idx)]
```
assuming `L.idx` has been configured correctly.

To aid in the configuration of `L.idx`, the field `indices` is constructed
such that for a move limit ``\\delta``, `L.idx = L.indices[δ]`.
"""
mutable struct MoveLUT{T}
    """
    Vector of destination addresses from the base address. Sorted in 
    increasing order of distance from the base addresses according to the 
    distance metric of the parent `SAStruct`.
    """
    targets :: Vector{T}

    """
    The index of the last entry in `targets` that is within the current move 
    distance limit of the base address.
    """
    idx :: Int

    """
    Cached `idx` for various move distance limits.
    """
    indices :: Vector{Int}
end

# Get a random element of distance "d"
function Base.rand(m::MoveLUT) 
    @inbounds target = m.targets[rand(1:m.idx)]
    return target
end

"""
This move generator precomputes all of the valid moves for each class at all
addresses, and references this cached database to generator moves.

Standard classes are used to index into the first level of `moves`. The inner
dictionary is a mapping from a base address to a [`MoveLUT`](@ref) for that
address.
"""
mutable struct CachedMoveGenerator{T} <: AbstractMoveGenerator
    moves :: Vector{Dict{T, MoveLUT{T}}}

    CachedMoveGenerator{T}() where T = new{T}(Dict{T, MoveLUT{T}}[])
end
CachedMoveGenerator(sa_struct::SAStruct{A,U,D}) where {A,U,D} = 
    CachedMoveGenerator{location_type(sa_struct.maptable)}()

# Configure the distance limit to be the maximum value in the distance table
# to be sure that initially, a task may be moved anywhere on the proecessor
# array.
distancelimit(::CachedMoveGenerator, sa_struct) = Int(maximum(sa_struct.distance))

function initialize!(
        move_generator :: CachedMoveGenerator{T}, 
        sa_struct :: SAStruct, 
        limit
    ) where T

    maptable = sa_struct.maptable
    num_classes = length(maptable.normal)

    moves = map(1:num_classes) do class
        # Get all locations that can be occupied by this class.
        class_locations = getlocations(maptable, class)

        # Create a dictionary of MoveLUTs for this class.
        return Dict(map(class_locations) do source
            source_address = getaddress(source)

            # Define a function that returns the distance of a location from
            # the current source address.
            dist(x) = sa_struct.distance[source_address, getaddress(x)]

            # Sort destinations for this address by distance.
            dests = sort(
                class_locations;
                # Comparison of distance. If distances are equal, sort by
                # CartesianIndex for easier testing.
                lt = (x, y) -> dist(x) < dist(y) || 
                    (dist(x) == dist(y) && getaddress(x) < getaddress(y))
            )

            # Create an auxiliary look up vector.
            θ = collect(Iterators.filter(
                !iszero, 
                (findlast(x -> dist(x) <= i, dests) for i in 1:limit)
            ))

            return source => MoveLUT(dests, length(dests), θ)
        end)
    end

    move_generator.moves = moves
    return nothing
end

# Modify the index in each MoveLUT to correspond to the new limit.
function update!(
        move_generator::CachedMoveGenerator{T}, 
        sa_struct::SAStruct, 
        limit
    ) where T 

    for dict in move_generator.moves
        for lut in values(dict)
            lut.idx = lut.indices[min(length(lut.indices), limit)]
        end
    end
    return nothing
end


@propagate_inbounds function generate_move(
        sa_struct::SAStruct{A}, 
        move_generator::CachedMoveGenerator,
        node_idx,
    ) where {A <: Architecture} 

    node = sa_struct.nodes[node_idx]
    old_location = location(node)
    maptable = sa_struct.maptable
    # Get the equivalent class of the node
    class = getclass(node)
    # Get the address and component to move this node to
    if isnormal(class)
        new_location = rand(move_generator.moves[class][old_location])
    else
        new_location = rand(maptable.special[-class])
    end
    return new_location
end
