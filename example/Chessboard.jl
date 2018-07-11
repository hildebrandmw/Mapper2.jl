module Chessboard

using Mapper2


# For testing, we create a "chessboard" type architecture. The layour of the
# architecture is quite similar to the that in Example 3, but half of the tiles
# will be "black_squares", while the other half will be "white_squares"
#
# We will have 3 classes of tasks:
# "black" tasks - can only be mapped to black squares
# "white" tasks - can only be mapped to white squares
# "gray" tasks - can be mapped to both squares.
#
# 1/4 of tasks will be black, 1/4 will be white, and the remaining tasks will
# be gray.
#
# This will help test various neighbor and move generation capabilities of the
# Mapper.
@enum SquareColor White Black Gray

struct Chess <: AbstractArchitecture end

# Extend "ismappable" 
Mapper2.ismappable(::Type{Chess}, x) = haskey(x.metadata, "color")

# Two tasks are equivalent if they have the same color.
function Mapper2.isequivalent(::Type{Chess}, a::TaskgraphNode, b::TaskgraphNode) 
    a.metadata["color"] == b.metadata["color"]
end

function Mapper2.canmap(::Type{Chess}, t::TaskgraphNode, c::Component)
    haskey(c.metadata, "color") || return false

    task_color = t.metadata["color"]
    component_color = c.metadata["color"]

    # Match by color.
    return task_color == Gray || (task_color == component_color)
end

################################################################################
# Architecture
################################################################################

# Build mappable component
function mappable(color :: SquareColor)
    component = Component("square", metadata = Dict("color" => color))
    add_port(component, "in", "input")
    add_port(component, "out", "output")

    return component
end
# Since Crossbars are Mapper primitives, we are now ready to build our tile.
function build_tile(color :: SquareColor)
    tile = Component("tile")

    # Ports
    for direction in ("north", "east", "south", "west")
        add_port(tile, "$(direction)_in", "input")
        add_port(tile, "$(direction)_out", "output")
    end

    # Sub-components
    add_child(tile, mappable(color), "square")
    add_child(tile, build_mux(5, 5), "mux")

    # Links

    # Mux to Square
    add_link(tile, "square.out", "mux.in[4]")
    add_link(tile, "mux.out[4]", "square.in")

    # Mux to IO
    add_link(tile, "mux.out[0]", "north_out")
    add_link(tile, "mux.out[1]", "east_out")
    add_link(tile, "mux.out[2]", "south_out")
    add_link(tile, "mux.out[3]", "west_out")

    add_link(tile, "north_in", "mux.in[0]")
    add_link(tile, "east_in",  "mux.in[1]")
    add_link(tile, "south_in", "mux.in[2]")
    add_link(tile, "west_in",  "mux.in[3]")

    return tile
end

function architecture(dim)
    arch = TopLevel{Chess, 2}("architecture")

    # Instantiate squares
    for (row, col) in Iterators.product(1:dim, 1:dim)
        address = Address(row, col)
        color = isodd(row + col) ? White : Black
        add_child(arch, build_tile(color), address)
    end

    # Connect cores
    source_rule(x) = true
    dest_rule(x) = true

    offsets = (
        Address(-1, 0),
        Address( 1, 0),
        Address( 0, 1),
        Address( 0,-1),
    )

    source_ports = ("north_out", "south_out", "east_out", "west_out")
    dest_ports =   ("south_in",  "north_in",  "west_in",  "east_in")

    # Create the "offset_rule" iterator by zipping offsets, source_ports, and
    # dest_ports together.
    offset_rules = zip(offsets, source_ports, dest_ports)
    connection_rule(arch, offset_rules, source_rule, dest_rule)

    return arch
end

################################################################################
# Taskgraph
################################################################################
function build_taskgraph(ntasks, nedges)
    colors = [White, Black, Gray, Gray]
    tasks = [
         TaskgraphNode(string(i), Dict("color" => colors[mod(i, 4) + 1]))
        for i in 1:ntasks
    ]
    
    edges = map(1:nedges) do _
        source = rand(1:ntasks)
        dest = rand(1:ntasks)

        return TaskgraphEdge(string(source), string(dest))
    end

    return Taskgraph("taskgraph", tasks, edges)
end

################################################################################
# Map
################################################################################
function build_map(dim, ntasks, nedges)
    arch = architecture(dim)
    taskgraph = build_taskgraph(ntasks, nedges)
    return NewMap(arch, taskgraph)
end

end
