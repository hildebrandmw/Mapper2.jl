module Mapper2

using IterTools
using JSON
using DataStructures
using ProgressMeter
using LightGraphs
using Formatting

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

#############
# Placement #
#############
# TODO: Modularize placement algorithms.
include("Placement/SAStruct.jl")
include("Placement/SAStructMethods.jl")
include("Placement/SAState.jl")
include("Placement/SA.jl")

include("Placement/InitialPlacement.jl")

###########
# Routing #
###########
# TODO

################################################################################
# Frameworks
################################################################################
include("Frameworks/Kilocore/Kilocore.jl")

################################################################################
# Misc Includes
################################################################################

# Profile Routines
include("benchmark.jl")

function testmap()
    options = Dict{Symbol, Any}()
    #arch = build_asap4()
    #arch = build_asap4(A = KCLink)
    arch = build_asap3()
    #arch = build_asap3(A = KCLink)
    sdc   = SimDumpConstructor("alexnet", "sort.json")
    #sdc  = SimDumpConstructor("alexnet", "alexnet-5-multiport-finetuned.json")
    tg   = apply_transforms(Taskgraph(sdc), sdc)
    return Map(arch, tg, options)
end

end # module
