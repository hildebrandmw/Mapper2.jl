################################################################################
# Architecture
################################################################################

# We want to be able to control the selection of the color for each tile to
# allow different patterns to be generated easily.
#
# Control this assignment with an ArchitectureColor that will control dispatch
# to methods throughout architecture construction.

"""
    abstract type ArchitectureColor end

Abstract supertype for color assignment rules.

API:

    `pick(::ArchitectureColor, addr::Address) :: SquareColor`

Allow selection of the color for the tile at `addr`.
"""
abstract type ArchitectureColor end

# Color squares in a chessboard pattern.
struct ChessboardColor <: ArchitectureColor end
# Determine color based on the sum of the components of the address.
pick(::ChessboardColor, addr) = isodd(sum(addr.I)) ? White : Black

struct HashColor <: ArchitectureColor end
pick(::HashColor, addr) = isodd(hash(addr)) ? White : Black

abstract type ArchitectureStyle end

struct Rectangle2D <: ArchitectureStyle end
portnames(::Rectangle2D) = ("north", "east", "south", "west")
nd(::Rectangle2D) = 2
function rules(::Rectangle2D)
    return tuple(
        ConnectionRule([
            Offset((-1, 0), "north_out", "south_in"),
            Offset((1, 0), "south_out", "north_in"),
            Offset((0, 1), "east_out", "west_in"),
            Offset((0, -1), "west_out", "east_in"),
        ]),
    )
end

struct Rectangle3D <: ArchitectureStyle end
portnames(::Rectangle3D) = ("north", "east", "south", "west", "up", "down")
nd(::Rectangle3D) = 3
function rules(::Rectangle3D)
    return tuple(
        ConnectionRule([
            Offset((-1, 0, 0), "north_out", "south_in"),
            Offset((1, 0, 0), "south_out", "north_in"),
            Offset((0, 1, 0), "east_out", "west_in"),
            Offset((0, -1, 0), "west_out", "east_in"),
            Offset((0, 0, 1), "up_out", "down_in"),
            Offset((0, 0, -1), "down_out", "up_in"),
        ]),
    )
end

#=
          ____          ____
         /    \        /    \
        /      \      /      \
   ____/  (0,1) \____/ (0,3)  \
  /    \        /    \        /
 /      \      /      \      /
/ (0,0)  \____/ (0,2)  \____/
\        /    \        /    \
 \      /      \      /      \
  \____/ (1,1)  \____/ (1,3)  \
  /    \        /    \        /
 /      \      /      \      /
/ (1,0)  \____/ (1,2)  \____/
\        /    \        /
 \      /      \      /
  \____/        \____/
=#

struct Hexagonal2D <: ArchitectureStyle end
portnames(::Hexagonal2D) = ("30", "90", "150", "210", "270", "330")
nd(::Hexagonal2D) = 2
function rules(::Hexagonal2D)
    return (
        # Rule to apply if the column address is even.
        ConnectionRule(
            [
                Offset((0, 1), "30_out", "210_in"),
                Offset((-1, 0), "90_out", "270_in"),
                Offset((0, -1), "150_out", "330_in"),
                Offset((1, -1), "210_out", "30_in"),
                Offset((1, 0), "270_out", "90_in"),
                Offset((1, 1), "330_out", "150_in"),
            ];
            address_filter = x -> iseven(x.I[2]),
        ),
        # Rule to apply if the column address is odd.
        ConnectionRule(
            [
                Offset((-1, 1), "30_out", "210_in"),
                Offset((-1, 0), "90_out", "270_in"),
                Offset((-1, -1), "150_out", "330_in"),
                Offset((0, -1), "210_out", "30_in"),
                Offset((1, 0), "270_out", "90_in"),
                Offset((0, 1), "330_out", "150_in"),
            ];
            address_filter = x -> isodd(x.I[2]),
        ),
    )
end

# Build mappable component
function mappable(color::SquareColor)
    component = Component("square"; metadata = Dict("color" => color))
    add_port(component, "in", Input)
    add_port(component, "out", Output)

    return component
end

# Since Crossbars are Mapper primitives, we are now ready to build our tile.
function build_tile(color::SquareColor, style::ArchitectureStyle)
    tile = Component("tile")

    # Ports
    directions = portnames(style)
    for direction in directions
        add_port(tile, "$(direction)_in", Input)
        add_port(tile, "$(direction)_out", Output)
    end

    # Sub-components
    add_child(tile, mappable(color), "square")

    # Add 1 to the numer of IO directions to allow a connection to be made to
    # the mappable core.
    nports = length(directions) + 1
    add_child(tile, build_mux(nports, nports), "mux")

    # Links

    # Mux to Square
    add_link(tile, "square.out", "mux.in[0]")
    add_link(tile, "mux.out[0]", "square.in")

    # Connect IO based on the provided directions.
    for (idx, direction) in enumerate(directions)
        add_link(tile, "mux.out[$idx]", "$(direction)_out")
        add_link(tile, "$(direction)_in", "mux.in[$idx]")
    end

    return tile
end

function architecture(
    tiles_per_side, style::ArchitectureStyle, color_rule::ArchitectureColor
)

    # Get the number of dimensions for this architecture.
    N = nd(style)

    arch = TopLevel{N}("architecture")

    # Instantiate squares
    for address in CartesianIndices(Tuple(tiles_per_side for _ in 1:N))
        color = pick(color_rule, address)
        add_child(arch, build_tile(color, style), address)
    end

    # Connect cores.
    for rule in rules(style)
        connection_rule(arch, rule)
    end

    return arch
end
