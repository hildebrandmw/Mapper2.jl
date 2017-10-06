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
# Top-level Map datatype
include("Map/Map.jl")

# Placement
include("Placement/SAStruct.jl")

################################################################################
# Frameworks
################################################################################
include("Frameworks/Kilocore/Kilocore.jl")

################################################################################
# Misc Includes
################################################################################

# Profile Routines
include("benchmark.jl")


#=
Just storing this here for later.
struct PackedFunctionCall
    function_name   ::Function
    args            ::Tuple
    function PackedFunctionCall(function_name, args = ())
        return new(function_name, args)
    end
end


#=
TODO: Error Checking.
=#
execute(pc::PackedFunctionCall, kwargs) = pc.function_name(pc.args..., kwargs...)
=#
end # module
