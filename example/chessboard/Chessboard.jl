module Chessboard

using Mapper2


# For testing, we create a "chessboard" type architecture. The layout of the
# architecture will either be rectangular 2D / 3D, or hexagonal 2D. About half
# of the tiles will be "black_squares", while the other half will be "white_squares"
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

struct Chess <: Architecture end

export  Chess,
        # Colors
        SquareColor, White, Black, Gray,
        # Architecture
        architecture,
        Rectangle2D, Rectangle3D, Hexagonal2D,
        ChessboardColor, HashColor,
        # Taskgraph
        AllGray, OddEven, Quarters,
        taskgraph, linegraph
        

include("Taskgraph.jl")
include("Architecture.jl")

# Extend "ismappable" 
Mapper2.ismappable(::Type{Chess}, x::Component) = haskey(x.metadata, "color")

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

Mapper2.getcapacity(::Type{Chess}, args...) = 5

################################################################################
# Map
################################################################################
function build_map(dim, ntasks, nedges)
    arch = architecture(dim, Val{2}(), ChessboardColor())
    taskgraph = build_taskgraph(ntasks, nedges)
    return NewMap(arch, taskgraph)
end

end
