module Mapper2

using IterTools
using JSON
using DataStructures

export Address, Port, Component, benchmark

# Flag for debug mode
const DEBUG = true
# Common types and operations
include("Common/Address.jl")
include("Common/Helper.jl")
# Architecture modeling related files.
include("Architecture/Architecture.jl")
include("Architecture/Constructors.jl")
# Taskgraph related files
include("Taskgraph/Taskgraph.jl")
include("Taskgraph/Transforms.jl")
include("Taskgraph/Constructors.jl")
# Architecture generators
include("Models/asap4.jl")

# Profile Routines
include("benchmark.jl")

end # module
