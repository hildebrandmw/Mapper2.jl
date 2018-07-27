using Mapper2
using Test

using Logging
disable_logging(Logging.BelowMinLevel)

# Add path to example architecture to the LOAD_PATH variable
for i in 1:2
    include(joinpath(Mapper2.PKGDIR, "example", "ex$i", "Example$i.jl"))
end
include(joinpath(Mapper2.PKGDIR, "example", "chessboard", "Chessboard.jl"))
using .Chessboard


using .Example1
using .Example2


# Taskgraph
include("Taskgraph.jl")

# Architecture
include("Architecture/Architecture.jl")

# Placement
include("Place/Placement.jl")
include("Place/MoveGenerators.jl")
include("Place/InitialPlacement.jl")

# Maps
include("Map/IntegrationTest.jl")
include("Map/SaveLoad.jl")
