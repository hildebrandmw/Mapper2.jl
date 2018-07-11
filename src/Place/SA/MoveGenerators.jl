# Control the move generation used by the Annealing scheme.
abstract type AbstractMoveGenerator end

struct SearchMoveGenerator <: AbstractMoveGenerator end
initialize!(::SearchMoveGenerator, args...) = nothing
update!(::SearchMoveGenerator, args...) = nothing

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
        sa::SAStruct{A}, 
        ::SearchMoveGenerator,
        cookie, 
        limit,
        upperbound,
    ) where {A <: AbstractArchitecture} 

    # Pick a random node
    index = rand(1:length(sa.nodes))
    canmove(A, sa.nodes[index]) || return false

    node = sa.nodes[index]
    old_address = getaddress(node)
    maptable = sa.maptable
    # Get the equivalent class of the node
    class = getclass(node)
    # Get the address and component to move this node to
    if isnormal(class)
        # Generate offset and check bounds.
        address = genaddress(old_address, limit, upperbound)
        # Now that we know our location is inbounds, find a component for it
        # to live in.
        isvalidaddress(maptable, class, address) || return false
        new_location = genlocation(maptable, class, address)
    else
        new_location = rand(maptable.special[-class])
    end
    # Perform the move and record enough information to undo the move. The
    # function "move_with_undo" will return false if the move is a swap and
    # the moved node cannot be placed.
    return move_with_undo(sa::SAStruct, cookie, index, new_location)
end

distancelimit(::SearchMoveGenerator, sa) = @compat maximum(last((CartesianIndices(sa.pathtable))).I)

# The idea for this data structure is that the Locations or Addresses within
# some distance D of each Location/Address is precomputed. When the distance
# limit changes, this structure will have to be modified - hence why it's
# mutable.

mutable struct MoveLUT{T}
    targets :: Vector{T}
    idx :: Int
    indices :: Vector{Int}
end

# Get a random element of distance "d"
function Base.rand(m::MoveLUT) 
    @inbounds target = m.targets[rand(1:m.idx)]
    return target
end

mutable struct CachedMoveGenerator{T}
    moves :: Vector{Dict{T, MoveLUT{T}}}

    CachedMoveGenerator{T}() where T = new{T}(Dict{T, MoveLUT{T}}[])
end

# Configure the distance limit to be the maximum value in the distance table
# to be sure that initially, a task may be moved anywhere on the proecessor
# array.
distancelimit(::CachedMoveGenerator, sa) = Int(maximum(sa.distance))

function initialize!(
        c :: CachedMoveGenerator{T}, 
        sa :: SAStruct, 
        limit = distancelimit(c, sa),
    ) where T
    maptable = sa.maptable
    num_classes = length(maptable.normal)

    moves = map(1:num_classes) do class
        # Get all locations that can be occupied by this class.
        class_locations = getlocations(maptable, class)

        # Create a dictionary of MoveLUTs for this class.
        return Dict(map(class_locations) do source
            source_address = getaddress(source)
            dist(x) = sa.distance[source_address, getaddress(x)]

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

    c.moves = moves
    return nothing
end

# Modify the index in each MoveLUT to correspond to the new limit.
function update!(c::CachedMoveGenerator{T}, sa::SAStruct, limit) where T 
    for dict in c.moves
        for lut in values(dict)
            lut.idx = lut.indices[min(length(lut.indices), limit)]
        end
    end
    return nothing
end


@propagate_inbounds function generate_move(
        sa::SAStruct{A}, 
        c::CachedMoveGenerator,
        cookie, 
        limit,
        upperbound,
    ) where {A <: AbstractArchitecture} 

    # Pick a random node
    index = rand(1:length(sa.nodes))
    canmove(A, sa.nodes[index]) || return false

    node = sa.nodes[index]
    old_location = location(node)
    maptable = sa.maptable
    # Get the equivalent class of the node
    class = getclass(node)
    # Get the address and component to move this node to
    if isnormal(class)
        new_location = rand(c.moves[class][old_location])
    else
        new_location = rand(maptable.special[-class])
    end
    # Perform the move and record enough information to undo the move. The
    # function "move_with_undo" will return false if the move is a swap and
    # the moved node cannot be placed.
    return move_with_undo(sa::SAStruct, cookie, index, new_location)
end
