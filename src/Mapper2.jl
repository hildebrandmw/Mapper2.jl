module Mapper2

using IterTools
export Address, Port, Component
# Common types and operations
include("Common/Address.jl")
# Architecture modeling related files.
include("Architecture/Architecture.jl")
include("Architecture/Constructors.jl")
# Architecture generators
include("Models/asap4.jl")

end # module
