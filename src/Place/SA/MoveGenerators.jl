# Control the move generation used by the Annealing scheme.
"""
API
---
* [`generate_move`](@ref)
* [`distancelimit`](@ref)
* [`initialize!`](@ref)
* [`update!`](@ref)

Implementations
---------------
* [`CachedMoveGenerator`](@ref)
"""
abstract type MoveGenerator end

# Document the interface for an MoveGenerator.
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
            sa_struct::SAStruct,
            move_generator::MoveGenerator,
            move_cookie,
        )

    # Pick a random address
    node_idx = rand(1:length(sa_struct.nodes))

    new_location = generate_move(sa_struct, move_generator, node_idx)
    return move_with_undo(sa_struct, move_cookie, node_idx, new_location)
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
\\text{distance}\\left( L_\\text{targets}[i] - \\alpha \\right) \\leq \\delta
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
mutable struct CachedMoveGenerator{T} <: MoveGenerator
    # Outer vector: class index
    # inner dict: starting Location
    moves :: Vector{Dict{T, MoveLUT{T}}}

    CachedMoveGenerator{T}() where T = new{T}(Dict{T, MoveLUT{T}}[])
end
CachedMoveGenerator(sa_struct::SAStruct{A,U,D}) where {A,U,D} =
    CachedMoveGenerator{location_type(sa_struct.maptable)}()

# Configure the distance limit to be the maximum value in the distance table
# to be sure that initially, a task may be moved anywhere on the proecessor
# array.
distancelimit(::CachedMoveGenerator, sa_struct) =
    maxdistance(sa_struct, sa_struct.distance)

function initialize!(move_generator::CachedMoveGenerator, sa_struct::SAStruct, limit)
    maptable = sa_struct.maptable
    num_classes = length(maptable.mask)

    moves = map(1:num_classes) do class
        # Get all locations that can be occupied by this class.
        class_locations = getlocations(maptable, class)

        # Create a dictionary of MoveLUTs for this class.
        return Dict(map(class_locations) do source
            # Define a function that returns the distance of a location from the current 
            # source address.
            dist(x) = getdistance(sa_struct.distance, source, x)

            # Sort destinations for this address by distance.
            dests = sort(
                class_locations;
                # Comparison of distance. If distances are equal, sort by
                # CartesianIndex for easier testing.
                lt = (x, y) -> dist(x) < dist(y) || 
                               (dist(x) == dist(y) && location(x) < location(y))
            )

            # Create an look up vector. 
            # Find the index of the last entry in `dests` whose distance from the source is 
            # within the limit `i`.
            θ = [findlast(x -> dist(x) <= i, dests) for i in 1:limit] 

            # Will throw if any entry in θ is `Nothing` - which is a good thing
            return source => MoveLUT(dests, length(dests), θ)
        end)
    end

    move_generator.moves = moves
    return nothing
end

# Modify the index in each MoveLUT to correspond to the new limit.
function update!(move_generator::CachedMoveGenerator, sa_struct::SAStruct, limit)
    for dict in move_generator.moves, lut in values(dict)
        lut.idx = lut.indices[min(length(lut.indices), limit)]
    end
    return nothing
end

@propagate_inbounds function generate_move(
        sa_struct::SAStruct,
        move_generator::CachedMoveGenerator,
        node_idx,
    )
    node = sa_struct.nodes[node_idx]

    # Unpack current location and class of the node. 
    this_location = location(node)
    class = getclass(node)

    # Use the class and current location to get a `MoveLUT` from the move generator
    move_lut = move_generator.moves[class][this_location] 

    # Return a random address from the move_lut.
    return rand(move_lut)
end
