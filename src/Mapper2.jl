module Mapper2

using IterTools
export Address, Port, Component, benchmark

# Common types and operations
include("Common/Address.jl")
include("Common/Helper.jl")
# Architecture modeling related files.
include("Architecture/Architecture.jl")
include("Architecture/Constructors.jl")
# Architecture generators
include("Models/asap4.jl")

# Profile Routines
include("benchmark.jl")

end # module
