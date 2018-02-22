module MapperCore

using ..Mapper2.Helper
using Reexport
using IterTools
using GZip
using JSON
using DataStructures
using MicroLogging

#include("Addresses.jl")
#@reexport using .Addresses

include("Taskgraphs.jl")
include("Architecture/Architecture.jl")
include("MapType/MapType.jl")

#@reexport using .Taskgraphs
#@reexport using .Architecture
#@reexport using .MapType

end
