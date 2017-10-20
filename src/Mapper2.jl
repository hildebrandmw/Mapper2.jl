module Mapper2

using IterTools
using DataStructures
using LightGraphs
using ProgressMeter
using Formatting

export Address, Port, Component, benchmark

# Set up directory paths
const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)

# Flag for debug mode
const DEBUG = true

###############################
# Common types and operations #
###############################

include("Common/Address.jl")
include("Common/Helper.jl")
# Architecture modeling related files.
include("Architecture/Architecture.jl")
include("Architecture/Constructors.jl")
# Taskgraph related files
include("Taskgraph/Taskgraph.jl")
# Top-level Map datatype
include("Map/Map.jl")
include("Map/Save.jl")

#############
# Placement #
#############

include("Placement/SA/SA.jl")

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
    #arch = build_asap3()
    arch  = build_asap3(A = KCLink)
    sdc   = SimDumpConstructor("553_cores_sum_cache")
    tg    = apply_transforms(Taskgraph(sdc), sdc)
    return NewMap(arch, tg)
end

end #module Mapper2
