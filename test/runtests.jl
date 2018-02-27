using Mapper2
using Base.Test

Mapper2.set_logging(:debug)

# Add path to example architecture to the LOAD_PATH variable
for i in 1:2
    push!(LOAD_PATH, joinpath(Mapper2.PKGDIR, "example", "ex$i"))
end

using Example1
using Example2

include("Taskgraph.jl")
include("Architecture.jl")
include("Placement.jl")
include("IntegrationTest.jl")
include("SaveLoad.jl")
include("InitialPlacement.jl")
