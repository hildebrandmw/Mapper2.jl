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
const DEBUG     = true
const USEPLOTS  = true

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
############
# Plotting #
############
# Optionally include plotting. Mapper will start up faster if plotting is turned
# off because Plots takes a while to load.
if USEPLOTS
    include("Plots/Plots.jl")
end
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
    #arch  = build_asap3(A = KCLink)
    dict = initialize_mem_dict()
    #arch = build_generic(33,33,2,dict, A = KCLink)
    sdc   = SimDumpConstructor("alexnet")
    tg    = apply_transforms(Taskgraph(sdc), sdc)
    return NewMap(arch, tg)
end

function initialize_mem_dict()
    # initialize memory addr and memory neighbor addr
    mem_dict = Dict(  Address(34,2,1) => [Address(33,2,1), Address(33,3,1)],
                      Address(34,4,1) => [Address(33,4,1), Address(33,5,1)],
                      Address(34,6,1) => [Address(33,6,1), Address(33,7,1)],
                      Address(34,8,1) => [Address(33,8,1), Address(33,9,1)],
                      Address(34,10,1) => [Address(33,10,1), Address(33,11,1)],
                      Address(34,12,1) => [Address(33,12,1), Address(33,13,1)],
                      Address(34,14,1) => [Address(33,14,1), Address(33,15,1)],
                      Address(34,16,1) => [Address(33,16,1), Address(33,17,1)],
                      Address(34,18,1) => [Address(33,18,1), Address(33,19,1)],
                      Address(34,20,1) => [Address(33,20,1), Address(33,21,1)],
                      Address(34,22,1) => [Address(33,22,1), Address(33,23,1)],
                      Address(34,24,1) => [Address(33,24,1), Address(33,25,1)],
                      Address(34,26,1) => [Address(33,26,1), Address(33,27,1)] )
    dict = Dict{String,Any}()
    # move to a bigger dict
    dict["memory_dict"] = mem_dict
    return dict
end

end #module Mapper2
