module Mapper2

using IterTools
using DataStructures
using LightGraphs
using ProgressMeter
using Formatting

export Address, Port, Component, benchmark

# Set up directory paths
const SRCDIR = dirname(@__FILE__())
const PKGDIR = dirname(SRCDIR)

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
    arch = build_asap4(A = KCLink)
    #arch = build_asap3()
    #arch = build_asap3(A = KCLink)
    #sdc   = SimDumpConstructor("sort.json")
    sdc  = SimDumpConstructor("alexnet-5-multiport-finetuned.json")
    tg   = apply_transforms(Taskgraph(sdc), sdc)
    return Map(arch, tg, options)
end

end # module
